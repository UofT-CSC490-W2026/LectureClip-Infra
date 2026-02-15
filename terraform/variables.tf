variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "lectureclip"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}
