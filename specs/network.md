# Spec: network (reusable Terraform module)
Inputs:
- name (string, required)
- cidr (string, default 10.20.0.0/16): a valid IPv4 CIDR from /16 to /20
- flow_log_bucket_arn (string, required): ARN of the bucket that receives flow logs
- az_ids (list of availability zone IDs, default ["apse2-az1", "apse2-az2"]): at least two, all different
Must: one VPC with DNS enabled; one private subnet per entry in az_ids, placed by AZ ID so it can
never move to another zone; no public IPs on launch; private access to S3 without internet, reaching
only buckets owned by this account; record ALL traffic as flow logs to the given bucket under the
prefix vpc-flow-logs/; the default security group must allow no traffic; the default network ACL
must not allow SSH (22) or RDP (3389) from the internet.
Must not: create an internet gateway, NAT gateway, Elastic IP or interface endpoint (cost); create or
change the log bucket's policy (the caller grants log delivery).
Outputs: vpc_id, private_subnet_ids.