# ============================================================================
# ENVIRONMENT: dev
# Branch: develop
# Usage:
#   terraform init -backend-config="environments/backend-dev.hcl" -reconfigure
#   terraform plan  -var-file="environments/dev.tfvars"
#   terraform apply -var-file="environments/dev.tfvars"
# ============================================================================

aws_region           = "ca-central-1"
account_id           = "757242163795"
project_name         = "lectureclip"
environment          = "dev"
create_oidc_provider = false

embedding_model_id  = "amazon.titan-embed-image-v1"
embedding_dim       = 1024
modal_embedding_url = ""

// uncomment this block and comment the previous block to use titan
# embedding_model_id  = "modal-jina-clip-v2"
# embedding_dim       = 1024
# modal_embedding_url = "https://kuakimnguu--lectureclip-embeddings-embedder-embed.modal.run"
