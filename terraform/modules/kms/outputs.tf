# ============================================================================
# KMS MODULE - OUTPUTS
# ============================================================================

output "key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.main.arn
}

output "key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.main.key_id
}

output "alias_arn" {
  description = "ARN of the KMS key alias"
  value       = aws_kms_alias.main.arn
}

output "alias_name" {
  description = "Name of the KMS key alias"
  value       = aws_kms_alias.main.name
}
