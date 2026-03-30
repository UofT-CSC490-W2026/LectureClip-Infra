output "user_pool_id" {
  description = "Cognito User Pool ID — set as VITE_USER_POOL_ID in the frontend build"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  description = "Cognito App Client ID — set as VITE_USER_POOL_CLIENT_ID in the frontend build"
  value       = aws_cognito_user_pool_client.web.id
}
