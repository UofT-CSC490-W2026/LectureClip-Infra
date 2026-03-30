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
embedding_model_id   = "modal-jina-clip-v2"
embedding_dim        = 1024
modal_embedding_url  = "https://kuakimnguu--lectureclip-embeddings-embedder-embed.modal.run"
chat_model_id        = "global.anthropic.claude-haiku-4-5-20251001-v1:0"
