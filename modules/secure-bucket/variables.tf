variable "name" {
  description = "Globally unique bucket name"
  type        = string
}
variable "force_destroy" {
  description = "Allow TF to force destroy the non-empty bucket, true only for this project"
  type        = bool
  default     = false
}
variable "access_logging_bucket" {
  description = "Bucket that receives S3 server access logs. null = no logging (only for the log bucket itself)"
  type        = string
  default     = null
}
variable "policy_docs" {
  description = "List of additional policy documents to attach to the bucket (CloudTrail writes, tc)"
  type        = list(string)
  default     = []
}
variable "retention_days" {
  description = "Number of days to keep old (noncurrent) object versions in the bucket before they expire"
  type        = number
  default     = 30
}
