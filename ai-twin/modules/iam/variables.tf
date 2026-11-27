variable "project" {
  description = "Project name used as the prefix for role and policy names."
  type        = string
  nullable    = false

  validation {
    # Kept short so "<project>-ci-plan-boundary" fits within IAM's 64-character name limit.
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,40}$", var.project))
    error_message = "project must be 1-40 characters: letters, digits and + = , . @ _ -."
  }
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI role, as owner/repo. It must match GitHub's capitalisation exactly, because IAM compares the token subject case-sensitively."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})/[A-Za-z0-9._-]{1,100}$", var.github_repo))
    error_message = "github_repo must be in the form owner/repo, for example my-org/infra."
  }
}

variable "state_bucket_arn" {
  description = "ARN of the S3 bucket that holds the Terraform state."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_arn))
    error_message = "state_bucket_arn must be an S3 bucket ARN, such as arn:aws:s3:::my-state-bucket, with no key path."
  }
}

variable "state_key_prefix" {
  description = "Key prefix the Terraform state lives under. It must end in /, for example envs/dev/."
  type        = string
  nullable    = false

  validation {
    # No wildcards (* or ?), so the prefix cannot widen the IAM resource patterns built from it.
    condition     = can(regex("^[A-Za-z0-9!_.'()=-]+(/[A-Za-z0-9!_.'()=-]+)*/$", var.state_key_prefix))
    error_message = "state_key_prefix must be a key prefix ending in / (for example envs/dev/). It must not start with / or contain empty segments, * or ?."
  }
}

variable "admin_user_arn" {
  description = "ARN of the only IAM user allowed to assume the auditor role."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:user/[A-Za-z0-9+=,.@_/-]+$", var.admin_user_arn))
    error_message = "admin_user_arn must be an IAM user ARN, for example arn:aws:iam::123456789012:user/alice."
  }
}
