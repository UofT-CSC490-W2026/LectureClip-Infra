# ============================================================================
# API GATEWAY MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "video_upload_function_name" {
  description = "Name of the video-upload Lambda function"
  type        = string
}

variable "video_upload_invoke_arn" {
  description = "Invoke ARN of the video-upload Lambda function"
  type        = string
}

variable "multipart_init_function_name" {
  description = "Name of the multipart-init Lambda function"
  type        = string
}

variable "multipart_init_invoke_arn" {
  description = "Invoke ARN of the multipart-init Lambda function"
  type        = string
}

variable "multipart_complete_function_name" {
  description = "Name of the multipart-complete Lambda function"
  type        = string
}

variable "multipart_complete_invoke_arn" {
  description = "Invoke ARN of the multipart-complete Lambda function"
  type        = string
}
