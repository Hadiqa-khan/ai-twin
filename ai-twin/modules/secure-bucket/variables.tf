variable "name" {
  description = "Globally unique name for the S3 bucket."
  type        = string
  nullable    = false

  validation {
    condition = (
      length(var.name) >= 3 &&
      length(var.name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.name)) &&
      !strcontains(var.name, "..") &&
      !can(regex("^\\d{1,3}(\\.\\d{1,3}){3}$", var.name)) &&
      !startswith(var.name, "xn--") &&
      !startswith(var.name, "sthree-") &&
      !endswith(var.name, "-s3alias") &&
      !endswith(var.name, "--ol-s3")
    )
    error_message = "name must be a valid S3 bucket name: 3-63 characters, only lowercase letters, digits, dots and hyphens, starting and ending with a letter or digit, not shaped like an IP address, and without a reserved prefix or suffix."
  }
}

variable "force_destroy" {
  description = "If true, Terraform deletes all objects and versions in the bucket when the bucket is destroyed."
  type        = bool
  default     = false
  nullable    = false
}

variable "access_logging_bucket" {
  description = "Name of an existing bucket that receives server access logs. null turns logging off. The target bucket must allow the logging.s3.amazonaws.com service principal to write to it."
  type        = string
  default     = null

  validation {
    condition = (
      var.access_logging_bucket == null ||
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.access_logging_bucket))
    )
    error_message = "access_logging_bucket must be null or a valid S3 bucket name."
  }

  validation {
    condition     = var.access_logging_bucket != var.name
    error_message = "access_logging_bucket must not be the bucket itself, because a bucket that logs to itself creates a log loop."
  }
}

variable "policy_docs" {
  description = "IAM policy JSON documents to merge into the bucket policy. Statement Sids must be unique across all documents and must not reuse this module's reserved Sids (DenyInsecureTransport, DenyOutdatedTls, DenyKmsEncryption)."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for doc in var.policy_docs : can(jsondecode(doc))])
    error_message = "Every entry in policy_docs must be a valid JSON string."
  }
}

variable "retention_days" {
  description = "Number of days a version is kept after it stops being the current version. After that it is deleted for good."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.retention_days >= 1 && floor(var.retention_days) == var.retention_days
    error_message = "retention_days must be a whole number of 1 or more."
  }
}
