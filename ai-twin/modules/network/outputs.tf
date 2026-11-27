output "vpc_id" {
  description = "ID of the VPC. It is only available once flow logs, the locked-down default security group and the default network ACL are in place."
  value       = aws_vpc.this.id

  depends_on = [
    aws_flow_log.this,
    aws_default_security_group.this,
    aws_default_network_acl.this,
    aws_vpc_endpoint.s3,
  ]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in the same order as var.az_ids."
  value       = [for az in var.az_ids : aws_subnet.private[az].id]

  depends_on = [
    aws_route_table_association.private,
    aws_default_network_acl.this,
    aws_vpc_endpoint.s3,
  ]
}
