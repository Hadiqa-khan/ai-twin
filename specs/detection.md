# Spec: detection (reusable Terraform module)
Inputs (all strings, all required):
- project
- alert_email (sensitive)
- cloudtrail_log_group_name: the CloudWatch Logs group that receives this account's CloudTrail trail
Must: email alert_email when ANY of these happen in this account. Everything is deployed in
ap-southeast-2, and every item must still be detected there:
- any GuardDuty finding
- any IAM Access Analyzer finding
- CloudTrail logging is stopped, a trail is deleted or updated, or its event selectors change
- an IAM user, access key or console login profile is created; a policy is attached to or put on a
  user; a user is added to a group; or a role is created, has its trust policy changed, or gets a
  policy attached or put on it
- VPC flow logs are deleted
- an S3 bucket policy or ACL is changed or deleted, or a bucket's or the account's public access
  block is changed or removed
- anything that would silence this alerting: any of this module's own alerting components, the
  alert topic or its access policy, the GuardDuty detector or the Access Analyzer is disabled,
  changed or deleted; the alert subscription is removed; or the trail's log group is deleted
Every named resource the module creates starts with "<project>-".
The alert topic's resource policy may grant publishing only to this module's own "<project>-" components.
Must not: use paid KMS keys.
Outputs: topic_arn, rule_names, alarm_names.