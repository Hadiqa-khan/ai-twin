variable "project" {
  type = string
}
variable "github_repo" {
  type = string
}
variable "alert_email" {
  type      = string
  sensitive = true
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be an email address."
  }
}

variable "state_bucket" {
  type = string
}

variable "access_log_bucket" {
  type = string
}

variable "admin_user_name" {
  type    = string
  default = "hadiqa-admin"
}
variable "enable_detection" {
  description = "false = remove the human detection module, used on Day 2 to swap in the AI twin"
  type        = bool
  default     = true
}
