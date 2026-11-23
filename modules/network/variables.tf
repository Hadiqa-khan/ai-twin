variable "name" {
  type = string
}
variable "cidr" {
  type    = string
  default = "10.20.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0)) && try(tonumber(split("/", var.cidr)[1]) >= 16 && tonumber(split("/", var.cidr)[1]) <= 20, false)
    error_message = "cidr must be a valid IPv4 CIDR with a prefix length between /16 and /20 (AWS VPCs can't be bigger than /16; each subnet adds 8 bits and can't be smaller than /28)."
  }
}

variable "flow_log_bucket_arn" {
  description = "ARN of the log bucket that receives the flow logs"
  type        = string
}

variable "az_ids" {
  description = "AZ IDs, one private subnet per ID, at least two (an AZ ID is the same physical zone in every account)"
  type        = list(string)
  default     = ["apse2-az1", "apse2-az2"]
  validation {
    condition     = length(var.az_ids) >= 2 && length(distinct(var.az_ids)) == length(var.az_ids)
    error_message = "az_ids needs at least two different AZ IDs."
  }
}