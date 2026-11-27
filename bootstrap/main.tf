terraform {
  required_version = "~> 1.17.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
}

variable "project" {
  type = string
}

provider "aws" {
  region  = "us-east-1"
  profile = "hk"
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "Terraform"
      Stack     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "me" {}

locals {
  account_id             = data.aws_caller_identity.me.account_id
  access_log_bucket_name = "${var.project}-access-logs-${local.account_id}"
}

data "aws_iam_policy_document" "access_log_delivery" {
  statement {
    sid       = "S3ServerAccessLogsPolicy"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.project}-access-logs-${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3:::${var.project}-*-${local.account_id}"]
    }
  }
}

module "access-logs" {
  #checkov:skip=CKV_AWS_18:This IS the access-log bucket; logging it into itself would loop
  #trivy:ignore:AWS-0089  (this IS the access-log bucket)
  source        = "../modules/secure-bucket"
  name          = local.access_log_bucket_name
  force_destroy = true
  policy_docs   = [data.aws_iam_policy_document.access_log_delivery.json]
}

module "tfstate" {
  source                = "../modules/secure-bucket"
  name                  = "${var.project}-tfstate-${local.account_id}"
  access_logging_bucket = local.access_log_bucket_name
  depends_on            = [module.access-logs]
}

output "state_bucket" {
  value = module.tfstate.id
}
output "access_log_bucket" {
  value = module.access-logs.id
}
