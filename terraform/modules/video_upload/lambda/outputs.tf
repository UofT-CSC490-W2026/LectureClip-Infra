# ============================================================================
# LAMBDA MODULE - OUTPUTS
# ============================================================================

output "video_upload_function_arn" {
  description = "ARN of the video-upload Lambda function"
  value       = aws_lambda_function.video_upload.arn
}

output "video_upload_function_name" {
  description = "Name of the video-upload Lambda function"
  value       = aws_lambda_function.video_upload.function_name
}

output "video_upload_invoke_arn" {
  description = "Invoke ARN of the video-upload Lambda function"
  value       = aws_lambda_function.video_upload.invoke_arn
}

output "multipart_init_function_arn" {
  description = "ARN of the multipart-init Lambda function"
  value       = aws_lambda_function.multipart_init.arn
}

output "multipart_init_function_name" {
  description = "Name of the multipart-init Lambda function"
  value       = aws_lambda_function.multipart_init.function_name
}

output "multipart_init_invoke_arn" {
  description = "Invoke ARN of the multipart-init Lambda function"
  value       = aws_lambda_function.multipart_init.invoke_arn
}

output "multipart_complete_function_arn" {
  description = "ARN of the multipart-complete Lambda function"
  value       = aws_lambda_function.multipart_complete.arn
}

output "multipart_complete_function_name" {
  description = "Name of the multipart-complete Lambda function"
  value       = aws_lambda_function.multipart_complete.function_name
}

output "multipart_complete_invoke_arn" {
  description = "Invoke ARN of the multipart-complete Lambda function"
  value       = aws_lambda_function.multipart_complete.invoke_arn
}
