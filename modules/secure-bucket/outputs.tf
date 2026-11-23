output "id" {
  value      = aws_s3_bucket.this.id
  depends_on = [aws_s3_bucket_policy.this]
}
output "arn" {
  value      = aws_s3_bucket.this.arn
  depends_on = [aws_s3_bucket_policy.this]
}