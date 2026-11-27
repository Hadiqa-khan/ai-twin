variable "project" {
  description = "Project name used as the prefix for the names of resources this module creates."
  type        = string
  nullable    = false

  validation {
    # Kept short so "<project>-cloudtrail-to-logs" fits within IAM's 64-character role name limit.
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$", var.project))
    error_message = "project must be 1-40 characters: letters, digits, underscores and hyphens, starting with a letter or digit."
  }
}

variable "trail_name" {
  description = "Name of the CloudTrail trail."
  type        = string
  nullable    = false

  validation {
    condition = (
      length(var.trail_name) >= 3 &&
      length(var.trail_name) <= 128 &&
      can(regex("^[A-Za-z0-9]+([._-][A-Za-z0-9]+)*$", var.trail_name)) &&
      !can(regex("^\\d{1,3}(\\.\\d{1,3}){3}$", var.trail_name))
    )
    error_message = "trail_name must be 3-128 characters: letters, digits, dots, underscores and hyphens. It must start and end with a letter or digit, must not have two of . _ - next to each other, and must not look like an IP address."
  }
}

variable "log_bucket_id" {
  description = "Name (not ARN) of the existing S3 bucket that receives CloudTrail log files. The caller must grant cloudtrail.amazonaws.com permission to write to it. This module does not change the bucket's policy."
  type        = string
  nullable    = false

  validation {
    condition = (
      !startswith(var.log_bucket_id, "arn:") &&
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.log_bucket_id))
    )
    error_message = "log_bucket_id must be an S3 bucket name such as my-log-bucket, not an ARN."
  }
}
