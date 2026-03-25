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

output "api_base_url" {
  description = "Base URL for all API endpoints"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "uploads_endpoint" {
  description = "POST /uploads — generate a pre-signed URL for direct video upload"
  value       = "${aws_api_gateway_stage.main.invoke_url}/uploads"
}

output "multipart_init_endpoint" {
  description = "POST /multipart/init — initialize a multipart upload and get part URLs"
  value       = "${aws_api_gateway_stage.main.invoke_url}/multipart/init"
}

output "multipart_complete_endpoint" {
  description = "POST /multipart/complete — assemble uploaded parts into a final object"
  value       = "${aws_api_gateway_stage.main.invoke_url}/multipart/complete"
}

output "query_endpoint" {
  description = "POST /query — semantic search over lecture transcript segments"
  value       = "${aws_api_gateway_stage.main.invoke_url}/query"
}

output "kms_key_id" {
  description = "ID of the KMS encryption key"
  value       = module.kms.key_id
}

output "audio_transcription_state_machine_arn" {
  description = "ARN of the audio transcription Step Functions state machine"
  value       = module.video_processing_step_functions.state_machine_arn
}

output "transcriptions_table_name" {
  description = "DynamoDB table that tracks Amazon Transcribe jobs"
  value       = module.video_processing_database.transcriptions_table_name
}
