# ============================================================================
# ENVIRONMENT: eval
# Branch: eval
# Usage:
#   terraform init -backend-config="environments/backend-eval.hcl"
#   terraform plan  -var-file="environments/eval.tfvars"
#   terraform apply -var-file="environments/eval.tfvars"
# ============================================================================

aws_region           = "ca-central-1"
account_id           = "757242163795"
project_name         = "lectureclip"
environment          = "eval"
create_oidc_provider = false
embedding_model_id   = "amazon.titan-embed-image-v1"
embedding_dim        = 1024
modal_embedding_url  = ""
