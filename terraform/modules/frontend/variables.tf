# ============================================================================
# FRONTEND MODULE - VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "github_access_token" {
  description = "GitHub personal access token for Amplify to pull from the App repo"
  type        = string
  sensitive   = true
}

variable "api_base_url" {
  description = "Base URL of the API Gateway stage, injected as VITE_API_BASE_URL"
  type        = string
}
