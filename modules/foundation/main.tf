# Callers must give CloudTrail write access to log_bucket_id (s3:GetBucketAcl, and s3:PutObject on
# cloudtrail/AWSLogs/<account>/*). envs/dev does this in its log_delivery policy, passed to secure-bucket.
data "aws_caller_identity" "me" {}
#trivy:ignore:AWS-0015  (SSE-S3 on the log bucket; a KMS CMK costs money and is on the roadmap)
resource "aws_cloudtrail" "main" {
  #checkov:skip=CKV_AWS_35:SSE-S3 on the log bucket; KMS CMK for CloudTrail is on the roadmap
  #checkov:skip=CKV_AWS_252:Alerting goes through EventBridge, not a trail SNS topic
  name                          = var.trail_name
  s3_bucket_name                = var.log_bucket_id
  s3_key_prefix                 = "cloudtrail"
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.trail_to_logs.arn
  depends_on                 = [aws_iam_role_policy.trail_to_logs]
}
#trivy:ignore:AWS-0017  (encrypted at rest by default; a KMS CMK costs money and is on the roadmap)
resource "aws_cloudwatch_log_group" "trail" {
  #checkov:skip=CKV_AWS_158:No KMS key (cost); the S3 copy of the trail is the long-term record
  #checkov:skip=CKV_AWS_338:7-day retention keeps this inside the CloudWatch free tier; the S3 copy is kept longer
  name              = "/aws/cloudtrail/${var.trail_name}"
  retention_in_days = 7
}
#who may assume the role
data "aws_iam_policy_document" "trail_to_logs_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.me.account_id]
    }
  }
}
resource "aws_iam_role" "trail_to_logs" {
  name               = "${var.project}-cloudtrail-to-logs"
  assume_role_policy = data.aws_iam_policy_document.trail_to_logs_trust.json
}
#permission policy for What the role is allowed
data "aws_iam_policy_document" "trail_to_logs" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:log-stream:*"]
  }
}

resource "aws_iam_role_policy" "trail_to_logs" {
  name   = "write-to-trail-log-group"
  role   = aws_iam_role.trail_to_logs.id
  policy = data.aws_iam_policy_document.trail_to_logs.json
}

resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_accessanalyzer_analyzer" "external" {
  analyzer_name = "${var.project}-external-access"
  type          = "ACCOUNT"
}

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}
#trivy:ignore:AWS-0062  (no forced expiry, following NIST SP 800-63B and current CIS guidance)
resource "aws_iam_account_password_policy" "this" {
  #checkov:skip=CKV_AWS_9:No forced expiry, following NIST SP 800-63B and current CIS guidance; length, MFA and reuse prevention instead
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
}
