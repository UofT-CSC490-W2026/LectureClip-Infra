output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_app_role_arn" {
  description = "ARN of the GitHub Actions OIDC role for the App repo (Lambda deployments)"
  value       = aws_iam_role.github_actions_app.arn
}
