variable "project" {
  type = string
}

variable "github_repo" {
  description = "GitHub repo name, owner/repo"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+(@[0-9]+)?/[A-Za-z0-9._-]+(@[0-9]+)?$", var.github_repo))
    error_message = "github_repo must be owner/repo, e.g. Hadiqa-khan/ai-twin."
  }
}

variable "admin_user_arn" {
  description = "The person who may assume the auditor role (with MFA) to view or inspect the events"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:user/.+$", var.admin_user_arn))
    error_message = "admin_user_arn must be an IAM user ARN."
  }
}

variable "state_bucket_arn" {
  type = string
  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9.-]+$", var.state_bucket_arn))
    error_message = "state_bucket_arn must be an S3 bucket ARN (arn:aws:s3:::name)."
  }
}

variable "state_key_prefix" {
  type        = string
  description = "State Key prefix CI may read and lock."
  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*/$", var.state_key_prefix))
    error_message = "state_key_prefix must look like envs/dev/"
  }
}
