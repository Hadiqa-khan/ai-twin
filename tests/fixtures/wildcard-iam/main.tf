#Deliberately insecure config for CI to reject
resource "aws_iam_policy" "open" {
  name = "fixture-admin-do-not-apply"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}
