# Accepted exceptions

| Check | Where | Why accepted | Revisit when |
|---|---|---|---|
| CKV_AWS_18 / Trivy AWS-0089 (no access logging) | bootstrap access_logs bucket | It is the access-log bucket; logging into itself would loop | Never |
| CKV_AWS_145 / Trivy AWS-0132 (no KMS CMK) | secure-bucket module | SSE-S3 is free; KMS costs money; log buckets can't use SSE-KMS | If budget allows KMS |
| CKV_AWS_144 (no cross-region replication) | secure-bucket module | Single-region lab | Multi-region version |
| CKV2_AWS_62 (no event notifications) | secure-bucket module | Not needed for log storage | Never |
| NACL ingress rule 110: TCP 32768–65535 from 0.0.0.0/0 | modules/network | Return traffic for connections the subnets start (e.g. S3 via the gateway endpoint). NACLs are stateless and can't use prefix lists. No internet gateway or NAT, so nothing on the internet can reach these subnets | If an internet gateway or NAT is ever added |
| NACL egress: allow all | modules/network | No route to the internet exists; the only way out is the S3 endpoint, which its own policy restricts | If an internet gateway or NAT is ever added |
| S3 endpoint policy uses Principal "*" | modules/network | Endpoint policies are written with Principal "*". The aws:ResourceAccount condition limits it to buckets this account owns | Never |
| S3 endpoint blocks AWS-owned buckets (side effect) | modules/network | Deliberate: no workloads run in these subnets. EC2/ECS here would need an allow-list for dnf repos, ECR layers and SSM buckets | If EC2 or ECS is added |
| CKV_AWS_356 ("*" as resource) | modules/iam: boundary | Read-only Get/List/Describe; most can't be resource-scoped. Only writes: the state lock file under state_key_prefix. Denies (tampering, identity creation, IAM escalation) are defence-in-depth, since the Allows are read-only today | Narrow wildcards to the calls CloudTrail shows after the first CI plan |
| CKV_AWS_356 ("*" as resource) | modules/iam: ci_plan | Same read list, needed for terraform plan to refresh the baseline. Writes limited to the lock file only; CI can't modify or delete state | Same as above |
| Design note | modules/iam: auditor | Auditor uses AWS SecurityAudit as both its policy and its boundary: full read-only security view, no writes possible. Requires MFA within the last hour | None |
| Design note: shared CI role | modules/iam: ci_plan | PR and main runs share one role with DeleteObject on *.tflock, so a PR could force-unlock a main run. Worst case is a forced unlock, not state corruption; CI only plans | When an apply role is added: separate role for PR plans, or PR plans with -lock=false |
| Design note: blanket Deny on iam:CreateRole / iam:PassRole | modules/iam: boundary | Right for a plan-only role. A future apply role under this boundary couldn't create or pass the flow-logs service role | When an apply role is added: Deny CreateRole unless iam:PermissionsBoundary equals this boundary's ARN; scope PassRole with iam:PassedToService |