data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  # Split the VPC CIDR into 16 equal slots (a /16 gives /20 subnets, a /20 gives /24 subnets).
  subnet_newbits = 4
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

# One private subnet per AZ ID. Placing subnets by AZ ID rather than AZ name
# pins each one to a physical zone, because AZ names map to different zones
# in different accounts.
resource "aws_subnet" "private" {
  for_each = toset(var.az_ids)

  vpc_id                  = aws_vpc.this.id
  availability_zone_id    = each.key
  cidr_block              = cidrsubnet(var.cidr, local.subnet_newbits, index(var.az_ids, each.key))
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

# The private route table has no default route. Its only way out of the VPC is the S3 gateway endpoint.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Gateway endpoints are free. Only allow requests to buckets owned by this account.
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid       = "AllowOnlyThisAccountsBuckets"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = {
    Name = "${var.name}-s3"
  }
}

# Record all traffic (accepted and rejected) to the caller's bucket. Log
# delivery to S3 needs no IAM role. The caller's bucket policy grants access.
resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${var.flow_log_bucket_arn}/vpc-flow-logs/"

  tags = {
    Name = "${var.name}-flow-logs"
  }
}

# Take over the default security group and remove every rule, so it allows no traffic in or out.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-deny-all"
  }
}

# Take over the default network ACL. Rules are checked lowest number first:
# 1. Allow everything from inside the VPC (internal SSH/RDP still works).
# 2. Deny SSH and RDP from anywhere else (the internet).
# 3. Allow all other traffic, so return traffic and the S3 endpoint keep working.
resource "aws_default_network_acl" "this" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id
  subnet_ids             = [for subnet in aws_subnet.private : subnet.id]

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = var.cidr
    from_port  = 0
    to_port    = 0
  }

  ingress {
    rule_no    = 110
    action     = "deny"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 120
    action     = "deny"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 3389
    to_port    = 3389
  }

  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.name}-default"
  }
}
