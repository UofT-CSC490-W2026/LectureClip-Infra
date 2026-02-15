# ============================================================================
# OUTPUTS
# ============================================================================

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = aws_iam_role.github_actions.arn
}

output "user_videos_s3_bucket_name" {
  description = "Name of the S3 user videos bucket"
  value       = aws_s3_bucket.user_videos.id
}
