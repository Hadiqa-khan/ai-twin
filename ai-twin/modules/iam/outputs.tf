output "ci_plan_role_arn" {
  description = "ARN of the CI role that GitHub Actions assumes to run terraform plan. It is only available once its permissions are attached."
  value       = aws_iam_role.ci_plan.arn

  depends_on = [aws_iam_role_policy.ci_plan]
}

output "auditor_role_arn" {
  description = "ARN of the auditor role. It is only available once SecurityAudit is attached."
  value       = aws_iam_role.auditor.arn

  depends_on = [aws_iam_role_policy_attachment.auditor_security_audit]
}

output "boundary_arn" {
  description = "ARN of the customer-managed permission boundary on the CI role. The auditor role uses the AWS-managed SecurityAudit policy as its boundary."
  value       = aws_iam_policy.ci_boundary.arn
}
