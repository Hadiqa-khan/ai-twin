data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  # Built from its parts so the delivery role's trust policy can name the
  # trail without a dependency cycle (the trail needs the role first).
  trail_arn = "arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${var.trail_name}"
}

# ---------------------------------------------------------------------------
# CloudTrail -> CloudWatch Logs
# ---------------------------------------------------------------------------

# No kms_key_id: CloudWatch Logs encrypts log data at rest with its own keys at no cost.
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/${var.project}/cloudtrail/${var.trail_name}"
  retention_in_days = 7
}

# Only CloudTrail can assume this role, and only on behalf of this trail in this account.
data "aws_iam_policy_document" "cloudtrail_logs_trust" {
  statement {
    sid     = "CloudTrailForThisAccountOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

# The role can only create streams in, and write events to, this one log group.
data "aws_iam_policy_document" "cloudtrail_logs_write" {
  statement {
    sid    = "WriteToTrailLogGroupOnly"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:log-stream:*"]
  }
}

resource "aws_iam_role" "cloudtrail_logs" {
  name                 = "${var.project}-cloudtrail-to-logs"
  description          = "Lets CloudTrail deliver trail ${var.trail_name} to its CloudWatch Logs group."
  assume_role_policy   = data.aws_iam_policy_document.cloudtrail_logs_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  name   = "${var.project}-cloudtrail-to-logs"
  role   = aws_iam_role.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_logs_write.json
}

# ---------------------------------------------------------------------------
# CloudTrail
# ---------------------------------------------------------------------------

resource "aws_cloudtrail" "this" {
  name                          = var.trail_name
  s3_bucket_name                = var.log_bucket_id
  s3_key_prefix                 = "cloudtrail"
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_logs.arn

  # CloudTrail checks on create that the role can write to the log group.
  depends_on = [aws_iam_role_policy.cloudtrail_logs]
}

# ---------------------------------------------------------------------------
# GuardDuty
# ---------------------------------------------------------------------------

# New findings reach EventBridge within minutes. FIFTEEN_MINUTES (the
# shortest option) also sends updates to existing findings every 15 minutes,
# rather than every 6 hours by default.
resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# ---------------------------------------------------------------------------
# IAM Access Analyzer: the free external-access analyzer for this account.
# The paid unused-access analyzer is not created.
# ---------------------------------------------------------------------------

resource "aws_accessanalyzer_analyzer" "external_access" {
  analyzer_name = "${var.project}-external-access"
  type          = "ACCOUNT"
}

# ---------------------------------------------------------------------------
# Account-wide guardrails
# ---------------------------------------------------------------------------

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Uses the AWS-managed aws/ebs key, which is free. No customer-managed KMS key is set.
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# NIST SP 800-63B: long passwords, no forced expiry. Leaving max_password_age
# unset means passwords never expire.
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  password_reuse_prevention      = 24
  allow_users_to_change_password = true
  hard_expiry                    = false
}
