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
