variable "project" {
  description = "Project name. Every named resource this module creates starts with \"<project>-\"."
  type        = string
  nullable    = false

  validation {
    # Kept short so "<project>-access-analyzer-findings" fits within EventBridge's 64-character rule name limit.
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$", var.project))
    error_message = "project must be 1-32 characters: letters, digits, underscores and hyphens, starting with a letter or digit."
  }
}

variable "alert_email" {
  description = "Email address that receives every alert. AWS emails it a subscription confirmation for each alert topic, and alerts are only delivered after it is confirmed."
  type        = string
  nullable    = false
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "cloudtrail_log_group_name" {
  description = "Name of the CloudWatch Logs group, in this region, that receives this account's multi-region CloudTrail trail."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9._/#-]{1,512}$", var.cloudtrail_log_group_name))
    error_message = "cloudtrail_log_group_name must be a valid CloudWatch Logs group name (1-512 characters: letters, digits and . _ / # -)."
  }
}
