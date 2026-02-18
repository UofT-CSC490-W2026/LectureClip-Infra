# ============================================================================
# S3 MODULE - OUTPUTS
# ============================================================================

output "user_videos_bucket_id" {
  description = "ID of the user videos bucket"
  value       = aws_s3_bucket.user_videos.id
}

output "user_videos_bucket_arn" {
  description = "ARN of the user videos bucket"
  value       = aws_s3_bucket.user_videos.arn
}

output "user_videos_sns_topic_arn" {
  description = "ARN of the user videos events SNS topic"
  value       = aws_sns_topic.user_videos_events.arn
}
