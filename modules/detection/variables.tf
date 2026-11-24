variable "project" {
  type = string
}
variable "alert_email" {
  type      = string
  sensitive = true
}
variable "cloudtrail_log_group_name" {
  description = "Cloudwatch logs group that receives this account's Cloudtrail trail"
  type        = string
}
