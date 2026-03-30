# ============================================================================
# RETRIEVAL MODULE - OUTPUTS
# ============================================================================

output "query_segments_function_name" {
  description = "Name of the query-segments Lambda function"
  value       = aws_lambda_function.query_segments.function_name
}

output "query_segments_function_arn" {
  description = "ARN of the query-segments Lambda function"
  value       = aws_lambda_function.query_segments.arn
}

output "query_segments_invoke_arn" {
  description = "Invoke ARN of the query-segments Lambda (used for API Gateway integration)"
  value       = aws_lambda_function.query_segments.invoke_arn
}

# Integration IDs consumed by the root module's deployment trigger so that
# changes to /query routes force an API Gateway redeployment.

output "query_post_integration_id" {
  description = "Integration ID for POST /query — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.query_post.id
}

output "query_options_integration_id" {
  description = "Integration ID for OPTIONS /query — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.query_options.id
}

output "query_segments_info_function_name" {
  description = "Name of the query-segments-info Lambda function"
  value       = aws_lambda_function.query_segments_info.function_name
}

output "query_segments_info_function_arn" {
  description = "ARN of the query-segments-info Lambda function"
  value       = aws_lambda_function.query_segments_info.arn
}

output "query_info_post_integration_id" {
  description = "Integration ID for POST /query-info — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.query_info_post.id
}

output "query_info_options_integration_id" {
  description = "Integration ID for OPTIONS /query-info — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.query_info_options.id
}

output "chat_post_integration_id" {
  description = "Integration ID for POST /chat — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.chat_post.id
}

output "chat_options_integration_id" {
  description = "Integration ID for OPTIONS /chat — consumed by the root module's deployment trigger"
  value       = aws_api_gateway_integration.chat_options.id
}
