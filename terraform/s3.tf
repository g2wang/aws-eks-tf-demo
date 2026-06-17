resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "logs" {
  bucket        = "eks-pod-logs-${random_string.suffix.result}"
  force_destroy = true # Allows deletion of the bucket even if it contains logs

  tags = {
    Name        = "EKS Pod Logs"
    Environment = "demo"
    Terraform   = "true"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "auto-expire-logs-14-days"
    status = "Enabled"

    expiration {
      days = 14
    }
  }
}
