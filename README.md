# LectureClip Infrastructure

AWS infrastructure for the LectureClip platform, provisioned with Terraform. This repo manages all cloud resources — networking, storage, compute, database, auth, and API — for the full video processing and retrieval pipeline.

Lambda function **code** is owned and deployed by the application CI repo (`LectureClip-App`) via `aws lambda update-function-code`. Terraform provisions the function shells and does not overwrite application deployments.

## Terraform Modules

| Module | Resources |
|--------|-----------|
| `video_upload/networking` | VPC, public/private subnets, NAT Gateway, Lambda security group |
| `video_upload/kms` | Customer-managed KMS key for S3 and CloudWatch encryption |
| `video_upload/storage` | User videos S3 bucket (KMS-encrypted, versioned) |
| `video_upload/iam` | Lambda execution role, GitHub Actions OIDC role |
| `video_upload/lambda` | Upload Lambda functions + Lambda artifacts S3 bucket |
| `video_upload/api_gateway` | REST API with upload endpoints (CORS-enabled) |
| `video_processing/aurora_db` | Aurora Serverless v2 PostgreSQL with pgvector extension |
| `video_processing/database` | DynamoDB table for Transcribe job state / task tokens |
| `video_processing/lambdas` | Transcription Lambdas (start-transcribe, process-transcribe) |
| `video_processing/step_function_workflow` | Step Functions state machine: S3 → Transcribe → embeddings |
| `video_processing/container` | ECS Fargate task for frame extraction and visual embeddings |
| `retrieval` | query-segments and query-segments-info Lambdas + `/query` and `/query-info` API endpoints |
| `auth` | Cognito User Pool (email sign-up/sign-in) |
| `cicd` | IAM roles and OIDC provider for GitHub Actions |
| `frontend` | AWS Amplify hosting for the React/Vite frontend |

## API Endpoints

| Method | Path | Lambda | Description |
|--------|------|--------|-------------|
| POST | `/upload` | `video-upload` | Returns a presigned PUT URL for direct upload (≤ 100 MB) |
| POST | `/multipart/init` | `multipart-init` | Creates a multipart upload, returns presigned part URLs |
| POST | `/multipart/complete` | `multipart-complete` | Assembles uploaded parts into a final S3 object |
| POST | `/register` | `register-user` | Upserts a user row in Aurora (called on every sign-in) |
| GET | `/lectures` | `list-lectures` | Returns all processed lectures for a user with presigned playback URLs |
| POST | `/query` | `query-segments` | Vector similarity search — returns matching segments (basic shape) |
| POST | `/query-info` | `query-segments-info` | Vector similarity search — returns segments with full transcript text and metadata |
| POST | `/chat` | `chat` | RAG chat: embed query → Aurora search → Claude Converse API → DynamoDB session |

All endpoints are CORS-enabled (`Access-Control-Allow-Origin: *`).

## Embedding Model Configuration

The embedding model is configured once at the root level and flows through to all lambdas and the ECS container. Set in the environment-specific `tfvars` file:

| Variable | Description | Default |
|----------|-------------|---------|
| `embedding_model_id` | Model ID for text/image embeddings | `amazon.titan-embed-image-v1` |
| `embedding_dim` | Embedding vector dimensionality | `1024` |
| `modal_embedding_url` | Modal endpoint URL (required for `modal-jina-clip-v2`) | `""` |

**Supported model IDs:**
- `amazon.titan-embed-image-v1` — AWS Bedrock Titan
- `modal-jina-clip-v2` — self-hosted jina-clip-v2 on Modal

Example (`environments/dev.tfvars`):
```hcl
embedding_model_id  = "modal-jina-clip-v2"
embedding_dim       = 1024
modal_embedding_url = "https://<workspace>--lectureclip-embeddings-embedder-embed.modal.run"
```

## Repository Structure

```
LectureClip-Infra/
├── terraform/
│   ├── main.tf                         # Root module — wires all modules together
│   ├── variables.tf
│   ├── outputs.tf
│   ├── environments/
│   │   ├── backend-dev.hcl             # Dev state backend config
│   │   ├── backend-prod.hcl            # Prod state backend config
│   │   ├── dev.tfvars
│   │   └── prod.tfvars
│   └── modules/
│       ├── video_upload/               # Upload pipeline infrastructure
│       │   ├── networking/             # VPC, subnets, NAT Gateway
│       │   ├── kms/                    # Customer-managed encryption key
│       │   ├── storage/                # S3 bucket for user videos
│       │   ├── iam/                    # Lambda execution + OIDC roles
│       │   ├── lambda/                 # Upload Lambda function shells
│       │   └── api_gateway/            # REST API + upload endpoints
│       ├── video_processing/           # Transcription + embedding pipeline
│       │   ├── aurora_db/              # Aurora Serverless v2 + pgvector
│       │   ├── database/               # DynamoDB for Transcribe task tokens
│       │   ├── lambdas/                # start-transcribe, process-transcribe
│       │   ├── step_function_workflow/ # State machine (S3 → Transcribe → embeddings)
│       │   └── container/              # ECS Fargate: frame extraction + visual embeddings
│       ├── retrieval/                  # Query and chat infrastructure
│       │   ├── main.tf                 # query-segments, query-segments-info Lambdas + API routes
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── auth/                       # Cognito User Pool
│       ├── cicd/                       # GitHub Actions OIDC + IAM roles
│       └── frontend/                   # AWS Amplify hosting
├── scripts/
│   └── bootstrap.sh                    # One-time setup: S3 backend bucket + DynamoDB lock table
├── .config/
│   ├── tf-lint/.tflint.hcl             # TFLint rules
│   └── cfn-guard/                      # cfn-guard policy rules
├── .github/workflows/
│   ├── on-push.yaml                    # Format check, validate, lint, security scan, deploy
│   └── on-pull-request.yaml            # terraform plan + PR comment
└── .pre-commit-config.yaml
```

## Setup

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) >= 1.6
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with appropriate credentials
- Git

### 1. Install dev tools

Installs Terraform, tflint, cfn-lint, cfn-guard, checkov, and pre-commit hooks:

```bash
make install
```

### 2. Authenticate with SSO

```bash
aws sso login --profile <your-profile-name>
export AWS_PROFILE=<your-profile-name>
```

### 3. Bootstrap the remote backend

Run once to create the S3 bucket and DynamoDB lock table used by the Terraform backend:

```bash
bash scripts/bootstrap.sh
```

This creates:
- S3 bucket `757242163795-workshop-tf-state` (versioned, encrypted, public access blocked)
- DynamoDB table `terraform-state-lock`

### 4. Initialize and deploy

```bash
cd terraform

# Dev environment
terraform init -backend-config="environments/backend-dev.hcl"
terraform plan  -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"

# Prod environment
terraform init -backend-config="environments/backend-prod.hcl" -reconfigure
terraform plan  -var-file="environments/prod.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

**Deploy order**: Provision `prod` first — it creates the shared GitHub OIDC provider (`create_oidc_provider = true`). Dev then looks up the existing provider (`create_oidc_provider = false`).

### 5. Get API endpoint URLs

```bash
terraform output
```

## Environments

Two isolated environments share the same AWS account but have separate Terraform state and independently-named resources:

| Environment | Branch | State key | Deploy trigger |
|-------------|--------|-----------|----------------|
| `dev` | `develop` | `lectureclip/dev/terraform.tfstate` | push to `develop` |
| `prod` | `main` | `lectureclip/prod/terraform.tfstate` | push to `main` |

All resource names follow `lectureclip-<env>-<resource>` (e.g. `lectureclip-dev-chat`).

## Deploying Changes

### Modifying existing infrastructure

Edit the relevant module under `terraform/modules/`, then:

```bash
cd terraform
terraform plan  -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### Adding a new module

1. Create `terraform/modules/<name>/main.tf`, `variables.tf`, `outputs.tf`
2. Add the module block to `terraform/main.tf`
3. Pass outputs to dependent modules as needed

### Updating Lambda code

Lambda code is managed by the application. Refer to the `LectureClip-App` repository for deployment instructions.

## CI/CD

### GitHub Actions variables required

| Variable | Description |
|----------|-------------|
| `AWS_REGION` | Target AWS region (e.g. `ca-central-1`) |
| `AWS_ACCOUNT_ID` | AWS account ID |
| `AWS_ROLE_TO_ASSUME_DEV` | IAM role ARN for OIDC-based auth (dev) |
| `AWS_ROLE_TO_ASSUME_PROD` | IAM role ARN for OIDC-based auth (prod) |

### Workflows

**on-push** (pushes to `main`/`develop`): Terraform format check, validate, tflint, checkov security scan, then deploy to the appropriate environment.

**on-pull-request**: Runs `terraform plan` against the target environment state and posts results as a PR comment. Also runs cfn-guard policy rules.

## Remote State

- **Backend**: S3
- **Bucket**: `757242163795-workshop-tf-state`
- **Keys**: `lectureclip/dev/terraform.tfstate` and `lectureclip/prod/terraform.tfstate`
- **Region**: `ca-central-1`
- **Locking**: Native S3 lock (`use_lockfile = true`, Terraform ≥ 1.6)
