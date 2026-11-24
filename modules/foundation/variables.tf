variable "project" {
  type = string
}
variable "trail_name" {
  type = string
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{1,126}[A-Za-z0-9]$", var.trail_name))
    error_message = "trail_name must be 3-128 characters: letters, digits, . _ -, starting and ending with a letter or digit."
  }
}
variable "log_bucket_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.log_bucket_id))
    error_message = "log_bucket_id must be a valid S3 bucket name (the name, not an ARN)."
  }
}
