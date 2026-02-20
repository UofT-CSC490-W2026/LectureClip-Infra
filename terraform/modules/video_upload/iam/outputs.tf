# ============================================================================
# IAM MODULE - OUTPUTS
# ============================================================================

output "video_upload_lambda_role_arn" {
  description = "ARN of the video upload Lambda execution role"
  value       = aws_iam_role.video_upload_lambda.arn
}

output "video_upload_lambda_role_name" {
  description = "Name of the video upload Lambda execution role"
  value       = aws_iam_role.video_upload_lambda.name
}
