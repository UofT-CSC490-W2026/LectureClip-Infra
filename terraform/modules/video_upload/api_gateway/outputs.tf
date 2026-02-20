# ============================================================================
# API GATEWAY MODULE - OUTPUTS
# ============================================================================

output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "base_url" {
  description = "Base invoke URL for the API stage"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "uploads_endpoint" {
  description = "Full URL for the POST /uploads endpoint"
  value       = "${aws_api_gateway_stage.main.invoke_url}/uploads"
}

output "multipart_init_endpoint" {
  description = "Full URL for the POST /multipart/init endpoint"
  value       = "${aws_api_gateway_stage.main.invoke_url}/multipart/init"
}

output "multipart_complete_endpoint" {
  description = "Full URL for the POST /multipart/complete endpoint"
  value       = "${aws_api_gateway_stage.main.invoke_url}/multipart/complete"
}
