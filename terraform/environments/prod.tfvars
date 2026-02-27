# ============================================================================
# ENVIRONMENT: prod
# Branch: main
# Usage:
#   terraform init -backend-config="environments/backend-prod.hcl"
#   terraform plan  -var-file="environments/prod.tfvars"
#   terraform apply -var-file="environments/prod.tfvars"
# ============================================================================

aws_region           = "ca-central-1"
account_id           = "757242163795"
project_name         = "lectureclip"
environment          = "prod"
create_oidc_provider = true
