You are writing a reusable Terraform module for AWS.
Versions: Terraform 1.17, provider hashicorp/aws ~> 6.73. Region: ap-southeast-2.
Return exactly three files: variables.tf, main.tf, outputs.tf.
Do not include a provider block, a backend block or a terraform block.
Implement this specification:
# Spec: iam (reusable Terraform module)
Inputs (all strings, all required):
- project
- github_repo: owner/repo
- state_bucket_arn: an S3 bucket ARN
- state_key_prefix: a key prefix ending in /, e.g. envs/dev/
- admin_user_arn: an IAM user ARN
Must:
- a GitHub Actions OIDC identity provider
- a CI role GitHub can assume only with tokens issued for AWS STS, and only from pull requests and
  the main branch of github_repo, able only
  to read this baseline's configuration (S3, EC2/VPC, IAM, CloudTrail, GuardDuty, Access Analyzer,
  EventBridge, SNS, CloudWatch, CloudWatch Logs), list state_bucket_arn, read Terraform state under
  state_key_prefix, and write only the state lock file
- an auditor role that only admin_user_arn can assume, only with MFA used in the last hour, with
  AWS's SecurityAudit read permissions
- sessions on both roles last at most one hour
- a permission boundary on every role: the auditor's boundary is the same SecurityAudit permissions;
  the CI role's boundary caps it to the access above and denies changing boundaries or policy
  versions, deleting policies, disabling logging or detection, creating IAM users or keys, and IAM privilege escalation
Must not: use "*" as an action, give write access to anything except the state lock file, or store any key.
Outputs: ci_plan_role_arn, auditor_role_arn, boundary_arn.