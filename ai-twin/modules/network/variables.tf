variable "name" {
  description = "Name used for the Name tag on every resource this module creates."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$", var.name))
    error_message = "name must be 1-63 characters: letters, digits, dots, underscores and hyphens, starting with a letter or digit."
  }
}

variable "cidr" {
  description = "IPv4 CIDR block for the VPC, with a prefix length from /16 to /20."
  type        = string
  default     = "10.20.0.0/16"
  nullable    = false

  validation {
    condition = try(
      can(regex("^\\d{1,3}(\\.\\d{1,3}){3}/\\d{1,2}$", var.cidr)) &&
      tonumber(split("/", var.cidr)[1]) >= 16 &&
      tonumber(split("/", var.cidr)[1]) <= 20 &&
      cidrsubnet(var.cidr, 0, 0) == var.cidr,
      false
    )
    error_message = "cidr must be a valid IPv4 network CIDR (for example 10.20.0.0/16) with a prefix length from /16 to /20, and its host bits must be zero."
  }
}

variable "flow_log_bucket_arn" {
  description = "ARN of the existing S3 bucket that receives VPC flow logs. The caller must grant delivery.logs.amazonaws.com permission to write to it. This module does not change the bucket's policy."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.flow_log_bucket_arn))
    error_message = "flow_log_bucket_arn must be an S3 bucket ARN, such as arn:aws:s3:::my-log-bucket, with no key path."
  }
}

variable "az_ids" {
  description = "Availability zone IDs (not names) to create one private subnet in each. At least two, all different."
  type        = list(string)
  default     = ["apse2-az1", "apse2-az2"]
  nullable    = false

  validation {
    condition     = length(var.az_ids) >= 2
    error_message = "az_ids must contain at least two availability zone IDs."
  }

  validation {
    condition     = length(distinct(var.az_ids)) == length(var.az_ids)
    error_message = "az_ids must not contain duplicates."
  }

  validation {
    condition     = length(var.az_ids) <= 16
    error_message = "az_ids can contain at most 16 entries, because the VPC CIDR is split into 16 subnet slots."
  }

  validation {
    condition     = alltrue([for az in var.az_ids : can(regex("^[a-z]+[0-9]+-az[0-9]+$", az))])
    error_message = "Each entry in az_ids must be an availability zone ID such as apse2-az1, not an availability zone name such as ap-southeast-2a."
  }
}
