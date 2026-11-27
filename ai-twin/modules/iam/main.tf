data "aws_partition" "current" {}

locals {
  partition           = data.aws_partition.current.partition
  security_audit_arn  = "arn:${local.partition}:iam::aws:policy/SecurityAudit"
  github_oidc_host    = "token.actions.githubusercontent.com"
  max_session_seconds = 3600

  state_objects_arn = "${var.state_bucket_arn}/${var.state_key_prefix}*"
  # S3 native locking (use_lockfile = true) writes "<state key>.tflock" next to the state file.
  state_lock_arn = "${var.state_bucket_arn}/${var.state_key_prefix}*.tflock"
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC identity provider. No secrets or keys are stored.
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${var.project}-github-actions"
  }
}

# ---------------------------------------------------------------------------
# CI (plan) role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ci_trust" {
  statement {
    sid     = "GitHubActionsOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Only tokens issued for AWS STS.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only pull requests and the main branch of this one repository.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values = [
        "repo:${var.github_repo}:pull_request",
        "repo:${var.github_repo}:ref:refs/heads/main",
      ]
    }
  }
}

# Everything the CI role may do. This document also forms the Allow part of
# the CI boundary, so the boundary caps the role to exactly this access.
data "aws_iam_policy_document" "ci_access" {
  statement {
    sid    = "ReadS3Configuration"
    effect = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetAccountPublicAccessBlock",
      "s3:GetAnalyticsConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetIntelligentTieringConfiguration",
      "s3:GetInventoryConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetMetricsConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadBaselineConfiguration"
    effect = "Allow"
    actions = [
      # EC2 / VPC. Describe only: ec2:Get* would include GetPasswordData.
      "ec2:Describe*",
      # IAM
      "iam:Get*",
      "iam:List*",
      # CloudTrail
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      # GuardDuty
      "guardduty:Get*",
      "guardduty:List*",
      # IAM Access Analyzer
      "access-analyzer:Get*",
      "access-analyzer:List*",
      # EventBridge
      "events:Describe*",
      "events:List*",
      # SNS
      "sns:Get*",
      "sns:List*",
      # CloudWatch
      "cloudwatch:Describe*",
      "cloudwatch:List*",
      # CloudWatch Logs: configuration only, no GetLogEvents or FilterLogEvents
      "logs:Describe*",
      "logs:List*",
      "logs:GetDataProtectionPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "ReadState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [local.state_objects_arn]
  }

  # The only write access anywhere: create and release the state lock file.
  statement {
    sid    = "WriteStateLockFile"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [local.state_lock_arn]
  }
}

# Explicit denies in the CI boundary. They still apply if someone later
# attaches broader permissions to the role.
data "aws_iam_policy_document" "ci_boundary" {
  source_policy_documents = [data.aws_iam_policy_document.ci_access.json]

  statement {
    sid    = "DenyBoundaryAndPolicyVersionChanges"
    effect = "Deny"
    actions = [
      "iam:PutRolePermissionsBoundary",
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutUserPermissionsBoundary",
      "iam:DeleteUserPermissionsBoundary",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyPolicyDeletion"
    effect = "Deny"
    actions = [
      "iam:DeletePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteUserPolicy",
      "iam:DeleteGroupPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyDisablingLogging"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
      "ec2:DeleteFlowLogs",
      "logs:DeleteLogGroup",
      "logs:DeleteLogStream",
      "logs:DeleteMetricFilter",
      "logs:DeleteSubscriptionFilter",
      "logs:PutRetentionPolicy",
      "s3:PutBucketLogging",
      "config:StopConfigurationRecorder",
      "config:DeleteConfigurationRecorder",
      "config:DeleteDeliveryChannel",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyDisablingDetection"
    effect = "Deny"
    actions = [
      "guardduty:DeleteDetector",
      "guardduty:UpdateDetector",
      "guardduty:DeleteMembers",
      "guardduty:DisassociateMembers",
      "guardduty:StopMonitoringMembers",
      "guardduty:DisassociateFromAdministratorAccount",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:CreateFilter",
      "guardduty:UpdateFilter",
      "guardduty:CreateIPSet",
      "guardduty:UpdateIPSet",
      "access-analyzer:DeleteAnalyzer",
      "access-analyzer:CreateArchiveRule",
      "access-analyzer:UpdateArchiveRule",
      "access-analyzer:ApplyArchiveRule",
      "events:DeleteRule",
      "events:DisableRule",
      "events:RemoveTargets",
      "sns:DeleteTopic",
      "sns:Unsubscribe",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DisableAlarmActions",
      "securityhub:DisableSecurityHub",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyIamUsersAndCredentials"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:UpdateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:CreateServiceSpecificCredential",
      "iam:UploadSSHPublicKey",
      "iam:UploadSigningCertificate",
      "iam:CreateVirtualMFADevice",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyIamPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:AttachUserPolicy",
      "iam:AttachGroupPolicy",
      "iam:PutRolePolicy",
      "iam:PutUserPolicy",
      "iam:PutGroupPolicy",
      "iam:AddUserToGroup",
      "iam:AddRoleToInstanceProfile",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:CreateOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:CreateSAMLProvider",
      "iam:UpdateSAMLProvider",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ci_boundary" {
  name        = "${var.project}-ci-plan-boundary"
  description = "Permission boundary for the ${var.project} CI plan role: read-only baseline access plus the state lock file, with explicit denies on tampering and privilege escalation."
  policy      = data.aws_iam_policy_document.ci_boundary.minified_json
}

resource "aws_iam_role" "ci_plan" {
  name                 = "${var.project}-ci-plan"
  description          = "Assumed by GitHub Actions (${var.github_repo}: pull requests and main) to run terraform plan."
  assume_role_policy   = data.aws_iam_policy_document.ci_trust.json
  max_session_duration = local.max_session_seconds
  permissions_boundary = aws_iam_policy.ci_boundary.arn
}

resource "aws_iam_role_policy" "ci_plan" {
  name   = "${var.project}-ci-plan-access"
  role   = aws_iam_role.ci_plan.id
  policy = data.aws_iam_policy_document.ci_access.minified_json
}

# ---------------------------------------------------------------------------
# Auditor role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "auditor_trust" {
  statement {
    sid     = "AdminUserWithRecentMfa"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.admin_user_arn]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }

    # MFA must have been used in the last hour. If the key is missing
    # (no MFA), NumericLessThan is false and the request is refused.
    condition {
      test     = "NumericLessThan"
      variable = "aws:MultiFactorAuthAge"
      values   = [tostring(local.max_session_seconds)]
    }
  }
}

resource "aws_iam_role" "auditor" {
  name                 = "${var.project}-auditor"
  description          = "Read-only security audit role. Only the admin user can assume it, with MFA used in the last hour."
  assume_role_policy   = data.aws_iam_policy_document.auditor_trust.json
  max_session_duration = local.max_session_seconds
  permissions_boundary = local.security_audit_arn
}

resource "aws_iam_role_policy_attachment" "auditor_security_audit" {
  role       = aws_iam_role.auditor.name
  policy_arn = local.security_audit_arn
}
