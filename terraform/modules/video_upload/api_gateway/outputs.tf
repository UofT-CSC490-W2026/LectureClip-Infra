# ============================================================================
# API GATEWAY MODULE - OUTPUTS
# Stage-dependent outputs (base_url, endpoints) live in the root module
# because the deployment and stage are managed there.
# ============================================================================

output "api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_execution_arn" {
  description = "Execution ARN used for lambda:InvokeFunction permissions"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "root_resource_id" {
  description = "Root resource ID — parent for top-level path parts"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

# Integration IDs are consumed by the root module to build the deployment
# trigger hash that forces a redeployment whenever any route changes.

output "upload_post_integration_id" {
  description = "Integration ID for POST /upload — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.upload_post.id
}

output "upload_options_integration_id" {
  description = "Integration ID for OPTIONS /upload — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.upload_options.id
}

output "multipart_init_post_integration_id" {
  description = "Integration ID for POST /multipart/init — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.multipart_init_post.id
}

output "multipart_init_options_integration_id" {
  description = "Integration ID for OPTIONS /multipart/init — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.multipart_init_options.id
}

output "multipart_complete_post_integration_id" {
  description = "Integration ID for POST /multipart/complete — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.multipart_complete_post.id
}

output "multipart_complete_options_integration_id" {
  description = "Integration ID for OPTIONS /multipart/complete — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.multipart_complete_options.id
}
