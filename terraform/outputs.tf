# ============================================================================
# OUTPUTS - ROOT MODULE
# ============================================================================

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

output "uploads_endpoint" {
  description = "POST /uploads — generate a pre-signed URL for direct video upload"
  value       = module.api_gateway.uploads_endpoint
}

output "multipart_init_endpoint" {
  description = "POST /multipart/init — initialize a multipart upload and get part URLs"
  value       = module.api_gateway.multipart_init_endpoint
}

output "multipart_complete_endpoint" {
  description = "POST /multipart/complete — assemble uploaded parts into a final object"
  value       = module.api_gateway.multipart_complete_endpoint
}

output "kms_key_id" {
  description = "ID of the KMS encryption key"
  value       = module.kms.key_id
}

output "audio_transcription_state_machine_arn" {
  description = "ARN of the audio transcription Step Functions state machine"
  value       = module.transcription.state_machine_arn
}

output "transcriptions_table_name" {
  description = "DynamoDB table that tracks Amazon Transcribe jobs"
  value       = module.transcription.transcriptions_table_name
}
