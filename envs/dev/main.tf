data "aws_caller_identity" "me" {}
data "aws_region" "current" {}
locals {
  account_id = data.aws_caller_identity.me.account_id
  region     = data.aws_region.current.region
  trail_name = "${var.project}-trail"
  log_bucket = "${var.project}-logs-${local.account_id}"
  trail_arn  = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
}
data "aws_iam_policy_document" "log_delivery" {
  statement {
    sid       = "CloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.log_bucket}"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
  statement {
    sid       = "CloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.log_bucket}/cloudtrail/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid       = "FlowLogsAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.log_bucket}"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
    }
  }
  statement {
    sid       = "FlowLogsWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.log_bucket}/vpc-flow-logs/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
    }
  }
}
module "logs" {
  source                = "../../modules/secure-bucket"
  name                  = local.log_bucket
  force_destroy         = true
  access_logging_bucket = var.access_log_bucket
  policy_docs           = [data.aws_iam_policy_document.log_delivery.json]
}
module "foundation" {
  source           = "../../modules/foundation"
  project          = var.project
  trail_name       = local.trail_name
  log_bucket_id    = module.logs.id
  enable_guardduty = false # AWS Free plan: GuardDuty not available
}
module "network" {
  source              = "../../modules/network"
  name                = "${var.project}-vpc"
  flow_log_bucket_arn = module.logs.arn
  az_ids              = ["use1-az1", "use1-az2"] # us-east-1
}

module "iam" {
  source           = "../../modules/iam"
  project          = var.project
  github_repo      = var.github_repo
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket}"
  state_key_prefix = "envs/dev/"
  admin_user_arn   = "arn:aws:iam::${local.account_id}:user/${var.admin_user_name}"
}
module "detection" {
  count                     = var.enable_detection ? 1 : 0
  source                    = "../../modules/detection"
  project                   = var.project
  alert_email               = var.alert_email
  cloudtrail_log_group_name = module.foundation.cloudtrail_log_group_name
}
