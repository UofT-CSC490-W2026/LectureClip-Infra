# ============================================================================
# VIDEO PROCESSING LAMBDAS MODULE - OUTPUTS
# ============================================================================

output "start_transcribe_arn" {
  description = "ARN of the start-transcribe Lambda function"
  value       = aws_lambda_function.start_transcribe.arn
}

output "start_transcribe_function_name" {
  description = "Name of the start-transcribe Lambda function"
  value       = aws_lambda_function.start_transcribe.function_name
}

output "process_transcribe_arn" {
  description = "ARN of the process-transcribe Lambda function"
  value       = aws_lambda_function.process_transcribe.arn
}

output "process_transcribe_function_name" {
  description = "Name of the process-transcribe Lambda function"
  value       = aws_lambda_function.process_transcribe.function_name
}
