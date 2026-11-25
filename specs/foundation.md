# Spec: foundation (reusable Terraform module)
Inputs (all strings, all required):
- project
- trail_name: a valid CloudTrail trail name
- log_bucket_id: the log bucket's name (not its ARN)
Must:
- a CloudTrail trail covering all regions and global services, with log file integrity validation,
  writing to log_bucket_id under the prefix cloudtrail
- also deliver the trail to a CloudWatch Logs log group kept for 7 days; the identity CloudTrail uses
  for that delivery may be used only by CloudTrail for this account, and may only write to that log group
- GuardDuty enabled, with findings reaching alerting within 15 minutes
- an IAM Access Analyzer for external access on this account
- account-wide S3 Block Public Access; EBS encryption by default
- an IAM password policy: 14+ characters, all character classes, reuse prevention 24, users may
  change their own password, no forced expiry (NIST SP 800-63B)
Must not: create paid analyzers or paid KMS keys; create or change the log bucket's policy (the
caller grants log delivery).
Outputs: trail_arn, guardduty_detector_id, cloudtrail_log_group_name.