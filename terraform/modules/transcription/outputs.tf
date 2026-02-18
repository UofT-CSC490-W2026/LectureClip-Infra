# ============================================================================
# TRANSCRIPTION MODULE - OUTPUTS
# ============================================================================

output "state_machine_arn" {
  description = "ARN of the audio transcription Step Functions state machine"
  value       = aws_sfn_state_machine.audio_transcription.arn
}

output "state_machine_name" {
  description = "Name of the audio transcription Step Functions state machine"
  value       = aws_sfn_state_machine.audio_transcription.name
}

output "transcriptions_table_name" {
  description = "Name of the DynamoDB table tracking transcription jobs"
  value       = aws_dynamodb_table.transcriptions.name
}

output "s3_trigger_function_name" {
  description = "Name of the s3-trigger Lambda function"
  value       = aws_lambda_function.s3_trigger.function_name
}
