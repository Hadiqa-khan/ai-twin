terraform {
  required_version = "~> 1.17.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
  backend "s3" {
    key          = "ai-twin/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-southeast-2"
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Variant   = "ai-twin"
    }
  }
}

variable "project" {
  type = string
}

variable "alert_email" {
  type      = string
  sensitive = true
}

# The human foundation's trail log group, shared by both runs (like GuardDuty).
# In terraform.tfvars: cloudtrail_log_group_name = "/aws/cloudtrail/[project]-trail"
variable "cloudtrail_log_group_name" {
  type = string
}

module "detection" {
  source                    = "../../modules/detection"
  project                   = var.project
  alert_email               = var.alert_email
  cloudtrail_log_group_name = var.cloudtrail_log_group_name
}
