# ============================================================================
# IAM MODULE - OUTPUTS
# ============================================================================

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = aws_iam_role.github_actions.arn
}

output "video_upload_lambda_role_arn" {
  description = "ARN of the video upload Lambda execution role"
  value       = aws_iam_role.video_upload_lambda.arn
}

output "video_upload_lambda_role_name" {
  description = "Name of the video upload Lambda execution role"
  value       = aws_iam_role.video_upload_lambda.name
}

output "github_actions_app_role_arn" {
  description = "ARN of the GitHub Actions OIDC role for the App repo (Lambda deployments)"
  value       = aws_iam_role.github_actions_app.arn
}
