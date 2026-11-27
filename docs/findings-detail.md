## modules/detection
## modules/foundation
## modules/iam
## modules/network
## modules/secure-bucket
- Trivy LOW AWS-0089: S3 Bucket Logging
## ai-twin/modules/detection
- Trivy HIGH AWS-0095: Unencrypted SNS topic.
- Checkov CKV_AWS_26: Ensure all data stored in the SNS topic is encrypted [aws_sns_topic.this]
## ai-twin/modules/foundation
- Trivy HIGH AWS-0015: CloudTrail should use Customer managed keys to encrypt the logs
- Trivy LOW AWS-0017: CloudWatch log groups should be encrypted using CMK
- Trivy MEDIUM AWS-0062: IAM Password policy should have expiry less than or equal to 90 days.
- Checkov CKV_AWS_338: Ensure CloudWatch log groups retains logs for at least 1 year [aws_cloudwatch_log_group.cloudtrail]
- Checkov CKV_AWS_158: Ensure that CloudWatch Log Group is encrypted by KMS [aws_cloudwatch_log_group.cloudtrail]
- Checkov CKV_AWS_252: Ensure CloudTrail defines an SNS Topic [aws_cloudtrail.this]
- Checkov CKV_AWS_35: Ensure CloudTrail logs are encrypted at rest using KMS CMKs [aws_cloudtrail.this]
- Checkov CKV_AWS_9: Ensure IAM password policy expires passwords within 90 days or less [aws_iam_account_password_policy.this]
- Checkov CKV2_AWS_3: Ensure GuardDuty is enabled to specific org/region [aws_guardduty_detector.this]
## ai-twin/modules/iam
- Checkov CKV_AWS_356: Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions [aws_iam_policy_document.ci_access]
## ai-twin/modules/network
## ai-twin/modules/secure-bucket
- Trivy LOW AWS-0089: S3 Bucket Logging
- Trivy HIGH AWS-0132: S3 encryption should use Customer Managed Keys
- Checkov CKV2_AWS_62: Ensure S3 buckets should have event notifications enabled [aws_s3_bucket.this]
- Checkov CKV_AWS_144: Ensure that S3 bucket has cross-region replication enabled [aws_s3_bucket.this]
- Checkov CKV_AWS_145: Ensure that S3 buckets are encrypted with KMS by default [aws_s3_bucket.this]
