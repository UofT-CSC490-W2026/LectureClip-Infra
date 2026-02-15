# ============================================================================
# S3 BUCKETS
# ============================================================================

# User videos bucket
resource "aws_s3_bucket" "user_videos" {
  bucket = "${var.project_name}-user-videos-${data.aws_caller_identity.current.account_id}"

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

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "user_videos" {
  bucket = aws_s3_bucket.user_videos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
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

# Publish S3 object-created events to SNS for downstream processing
resource "aws_sns_topic" "user_videos_events" {
  name = "${var.project_name}-user-videos-events"
}

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

resource "aws_s3_bucket_notification" "user_videos" {
  bucket = aws_s3_bucket.user_videos.id

  topic {
    topic_arn = aws_sns_topic.user_videos_events.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.user_videos_events]
}
