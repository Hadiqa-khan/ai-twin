output "ci_plan_role_arn" {
  value = aws_iam_role.ci_plan.arn
}
output "auditor_role_arn" {
  value = aws_iam_role.auditor.arn
}

output "boundary_arn" {
  value = aws_iam_policy.boundary.arn
}

