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

// uncomment this block and comment the next block to use Amazon Titan embedding model
# embedding_model_id   = "amazon.titan-embed-image-v1"
# embedding_dim        = 1024
# modal_embedding_url  = ""

embedding_model_id  = "modal-jina-clip-v2"
embedding_dim       = 1024
modal_embedding_url = "https://kuakimnguu--lectureclip-embeddings-embedder-embed.modal.run"
chat_model_id       = "global.anthropic.claude-haiku-4-5-20251001-v1:0"
