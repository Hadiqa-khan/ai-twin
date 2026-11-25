# Spec: secure-bucket (reusable Terraform module)
Inputs:
- name (string, required): globally unique bucket name
- force_destroy (bool, default false)
- access_logging_bucket (string, default null): bucket that receives server access logs; null = no logging
- policy_docs (list of policy JSON strings, default empty list)
- retention_days (number, default 30)
Must: block all public access; disable ACLs (the bucket owner owns every object); keep object
versions; encrypt at rest; reject any request that doesn't use TLS 1.2 or newer; send server access
logs to access_logging_bucket when it is set; expire old versions after retention_days; clean up
incomplete uploads after 7 days; merge policy_docs into the bucket policy; not expose id or arn to
callers until the bucket policy is in place (services that write to the bucket check it on create).
Must not: make anything public; use paid encryption keys.
Outputs: id, arn.