#Deliberately Insecure config for CI to reject
resource "aws_s3_bucket" "public" {
  bucket = "fixture-public-bucket-do-not-apply"
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket                  = aws_s3_bucket.public.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
