# ============================================================================
# VIDEO PROCESSING DATABASE MODULE - OUTPUTS
# ============================================================================

output "transcriptions_table_name" {
  description = "Name of the DynamoDB table used to track Transcribe jobs"
  value       = aws_dynamodb_table.transcriptions.name
}

output "transcriptions_table_arn" {
  description = "ARN of the DynamoDB table used to track Transcribe jobs"
  value       = aws_dynamodb_table.transcriptions.arn
}
