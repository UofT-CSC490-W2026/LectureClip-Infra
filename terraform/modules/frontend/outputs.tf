# ============================================================================
# FRONTEND MODULE - OUTPUTS
# ============================================================================

output "app_id" {
  description = "Amplify app ID"
  value       = aws_amplify_app.frontend.id
}

output "default_domain" {
  description = "Default Amplify-assigned domain for the app"
  value       = aws_amplify_app.frontend.default_domain
}

output "branch_url" {
  description = "HTTPS URL for the deployed branch"
  value       = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.frontend.default_domain}"
}
