# Callers must allow delivery.logs.amazonaws.com to write flow logs into the log bucket
# (envs/dev does this in its log_delivery policy document, passed to secure-bucket via policy_docs).
# Without it AWS tries to add its own bucket policy, which secure-bucket would then overwrite.

data "aws_region" "current" {}
data "aws_caller_identity" "me" {}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.name
  }
}
resource "aws_subnet" "private" {
  count                   = length(var.az_ids)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 8, count.index)
  availability_zone_id    = var.az_ids[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name}-private-${count.index}"
    Tier = "private"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid       = "OnlyThisAccountsBuckets"
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
      values   = [data.aws_caller_identity.me.account_id]
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
    Name = "${var.name}-s3-endpoint"
  }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-default-locked"
  }
}

resource "aws_default_network_acl" "this" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id
  subnet_ids             = aws_subnet.private[*].id

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
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 65535
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
    Name = "${var.name}-default-nacl"
  }
}

resource "aws_flow_log" "this" {
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = "${var.flow_log_bucket_arn}/vpc-flow-logs/"
  max_aggregation_interval = 600
  tags = {
    Name = "${var.name}-flow-logs"
  }
}