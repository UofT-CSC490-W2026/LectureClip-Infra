# ============================================================================
# ENVIRONMENT: dev
# Branch: develop
# Usage:
#   terraform init -backend-config="environments/backend-dev.hcl"
#   terraform plan  -var-file="environments/dev.tfvars"
#   terraform apply -var-file="environments/dev.tfvars"
# ============================================================================

aws_region           = "ca-central-1"
account_id           = "757242163795"
project_name         = "lectureclip"
environment          = "dev"
create_oidc_provider = false
