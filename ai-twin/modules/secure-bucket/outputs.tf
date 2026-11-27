output "id" {
  description = "Name of the bucket. It is only available once the bucket policy and the other security settings are in place."
  value       = aws_s3_bucket.this.id

  depends_on = [
    aws_s3_bucket_policy.this,
    aws_s3_bucket_public_access_block.this,
    aws_s3_bucket_ownership_controls.this,
    aws_s3_bucket_versioning.this,
    aws_s3_bucket_server_side_encryption_configuration.this,
    aws_s3_bucket_lifecycle_configuration.this,
    aws_s3_bucket_logging.this,
  ]
}

output "arn" {
  description = "ARN of the bucket. It is only available once the bucket policy and the other security settings are in place."
  value       = aws_s3_bucket.this.arn

  depends_on = [
    aws_s3_bucket_policy.this,
    aws_s3_bucket_public_access_block.this,
    aws_s3_bucket_ownership_controls.this,
    aws_s3_bucket_versioning.this,
    aws_s3_bucket_server_side_encryption_configuration.this,
    aws_s3_bucket_lifecycle_configuration.this,
    aws_s3_bucket_logging.this,
  ]
}
