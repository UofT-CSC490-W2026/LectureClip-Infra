# ============================================================================
# S3 MODULE - MAIN
# Manages S3 buckets and related resources
# ============================================================================

# User videos bucket
resource "aws_s3_bucket" "user_videos" {
  bucket = "${var.project_name}-user-videos-${var.account_id}"

  tags = {
    Name        = "${var.project_name}-user-videos"
    Environment = var.environment
    Purpose     = "User video uploads"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "user_videos" {
  bucket = aws_s3_bucket.user_videos.id

  versioning_configuration {
    status = "Enabled"
  }
}

# KMS encryption — presigned URLs inherit bucket-default SSE automatically
resource "aws_s3_bucket_server_side_encryption_configuration" "user_videos" {
  bucket = aws_s3_bucket.user_videos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# CORS — required for browser-based direct uploads and multipart part ETag collection
resource "aws_s3_bucket_cors_configuration" "user_videos" {
  bucket = aws_s3_bucket.user_videos.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "user_videos" {
  bucket = aws_s3_bucket.user_videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SNS topic for S3 events
resource "aws_sns_topic" "user_videos_events" {
  name = "${var.project_name}-user-videos-events"

  tags = {
    Name        = "${var.project_name}-user-videos-events"
    Environment = var.environment
  }
}

# SNS topic policy
resource "aws_sns_topic_policy" "user_videos_events" {
  arn = aws_sns_topic.user_videos_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3Publish"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.user_videos_events.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.user_videos.arn
          }
        }
      }
    ]
  })
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "user_videos" {
  bucket = aws_s3_bucket.user_videos.id

  topic {
    topic_arn = aws_sns_topic.user_videos_events.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.user_videos_events]
}
