locals {
  boundary_name = "${var.project}-permission-boundary"

  # Read-only actions Terraform needs to refresh THIS baseline, and nothing else.
  # Get/List/Describe calls mostly don't support resource-level permissions, so Resource "*" is required for them.

  baseline_read_actions = [
    "access-analyzer:Get*", "access-analyzer:List*",
    "cloudtrail:Describe*", "cloudtrail:Get*", "cloudtrail:List*",
    "cloudtrail:LookupEvents", "ec2:Describe*", "ec2:GetEbsEncryptionByDefault",
    "ec2:GetEbsDefaultKmsKeyID",
    "events:Describe*", "events:List*", "guardduty:Get*", "guardduty:List*",
    "iam:Get*", "iam:List*", "s3:GetBucket*", "s3:GetAccelerateConfiguration",
    "s3:GetLifecycleConfiguration",
    "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration",
    "s3:GetAccountPublicAccessBlock",
    "s3:ListAllMyBuckets", "sns:Get*", "sns:List*", "logs:Describe*", "logs:List*",
    "cloudwatch:Describe*", "cloudwatch:List*", "sts:GetCallerIdentity"
  ]
}

#GitHub OIDC

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

#Permission Boundary

data "aws_iam_policy_document" "boundary" {
  #checkov:skip=CKV_AWS_356:Read-only Get/List/Describe actions; most don't support resource-level permissions.
  statement {
    sid       = "CeilingReadBaseline"
    effect    = "Allow"
    actions   = local.baseline_read_actions
    resources = ["*"]
  }
  statement {
    sid    = "CeilingStateBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "CeilingStateRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.state_bucket_arn}/${var.state_key_prefix}*"]
  }

  statement {
    sid       = "CeilingStateLock"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/${var.state_key_prefix}*.tflock"]

  }
  #Deny takes precedence

  statement {
    sid    = "DenyBoundaryTamper"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
      "iam:DeleteUserPermissionsBoundary",
      "iam:PutUserPermissionsBoundary",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyDetectionTamper"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
      "guardduty:DeleteDetector",
      "guardduty:UpdateDetector",
      "ec2:DeleteFlowLogs",
      "access-analyzer:DeleteAnalyzer",
      "events:DeleteRule",
      "events:DisableRule",
      "events:RemoveTargets",
      "sns:DeleteTopic",
      "sns:Unsubscribe",
      "logs:DeleteLogGroup",
      "logs:DeleteMetricFilter",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DisableAlarmActions",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyIdentityAndEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateUser", "iam:CreateAccessKey", "iam:CreateLoginProfile",
      "iam:AttachUserPolicy", "iam:PutUserPolicy", "iam:CreateRole", "iam:PutRolePolicy",
      "iam:AttachRolePolicy", "iam:UpdateAssumeRolePolicy", "iam:PassRole",
      "iam:CreatePolicy", "iam:AddUserToGroup", "iam:PutGroupPolicy", "iam:AttachGroupPolicy"
    ]
    resources = ["*"]
  }
}

#IAM Boundary
resource "aws_iam_policy" "boundary" {
  name        = local.boundary_name
  description = "Maximum Permissions for the CI Plan role"
  policy      = data.aws_iam_policy_document.boundary.json
}

#Assume Role GitHub

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = ["repo:${var.github_repo}:pull_request",
      "repo:${var.github_repo}:ref:refs/heads/main", ]
    }
  }
}
resource "aws_iam_role" "ci_plan" {
  name                 = "${var.project}-ci-plan"
  description          = "GitHub Actions: terraform plan only (read + state lock)"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  permissions_boundary = aws_iam_policy.boundary.arn
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ci_plan" {
  #checkov:skip=CKV_AWS_356:Read-only Get/List/Describe actions; most don't support resource-level permissions. Only write: the state lock file
  statement {
    sid       = "ReadBaseline"
    effect    = "Allow"
    actions   = local.baseline_read_actions
    resources = ["*"]
  }
  statement {
    sid    = "StateList"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [var.state_bucket_arn]
  }
  statement {
    sid    = "StateRead"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = ["${var.state_bucket_arn}/${var.state_key_prefix}*"]
  }

  statement {
    sid    = "StateLockOnly"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${var.state_bucket_arn}/${var.state_key_prefix}*.tflock"]
  }

}
resource "aws_iam_policy" "ci_plan" {
  name        = "${var.project}-ci-plan"
  description = "CI Plan Policy for ${var.project}"
  policy      = data.aws_iam_policy_document.ci_plan.json
}

resource "aws_iam_role_policy_attachment" "ci_plan" {
  role       = aws_iam_role.ci_plan.name
  policy_arn = aws_iam_policy.ci_plan.arn
}

#Read only role for security operations
data "aws_iam_policy_document" "auditor_trust" {
  statement {
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
    condition {
      test     = "NumericLessThan"
      variable = "aws:MultiFactorAuthAge"
      values   = ["3600"]
    }
  }
}

resource "aws_iam_role" "auditor" {
  name                 = "${var.project}-auditor"
  assume_role_policy   = data.aws_iam_policy_document.auditor_trust.json
  permissions_boundary = "arn:aws:iam::aws:policy/SecurityAudit"
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "auditor" {
  role       = aws_iam_role.auditor.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
