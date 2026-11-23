# Accepted exceptions

| Check | Where | Why accepted | Revisit when |
|---|---|---|---|
| CKV_AWS_18 / Trivy AWS-0089 (no access logging) | bootstrap access_logs bucket | It is the access-log bucket; logging into itself would loop | Never |
| CKV_AWS_145 / Trivy AWS-0132 (no KMS CMK) | secure-bucket module | SSE-S3 is free; KMS costs money; log buckets can't use SSE-KMS | If budget allows KMS |
| CKV_AWS_144 (no cross-region replication) | secure-bucket module | Single-region lab | Multi-region version |
| CKV2_AWS_62 (no event notifications) | secure-bucket module | Not needed for log storage | Never |