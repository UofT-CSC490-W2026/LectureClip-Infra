# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Setup
```bash
make install          # Install all prerequisites (terraform, tflint, cfn-lint, cfn-guard, checkov, pre-commit)
scripts/bootstrap.sh  # Bootstrap the S3 + DynamoDB Terraform backend (run once)
```

### Terraform Workflow
All commands run from `terraform/`. Use environment-specific var and backend files:
```bash
# Dev environment
terraform init -backend-config="environments/backend-dev.hcl"
terraform plan  -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"

# Prod environment
terraform init -backend-config="environments/backend-prod.hcl" -reconfigure
terraform plan  -var-file="environments/prod.tfvars"
terraform apply -var-file="environments/prod.tfvars"

# Common commands
terraform init -backend=false  # Init without backend (for CI validation)
terraform destroy -var-file="environments/<env>.tfvars"
terraform output      # View all outputs (API endpoints, Cognito IDs, etc.)
terraform fmt -recursive  # Auto-format all .tf files
terraform validate
```

**Deploy order**: Provision `prod` first — it creates the shared GitHub OIDC provider (`create_oidc_provider = true`). Dev then looks up the existing provider (`create_oidc_provider = false`).

### Linting & Security
```bash
tflint --config .config/tf-lint/.tflint.hcl  # Run from terraform/ directory
checkov -d terraform/ --framework terraform
pre-commit run --all-files  # Run all pre-commit hooks
```

## Architecture

### Infrastructure Overview
LectureClip is a full-stack video processing and retrieval platform. This repo provisions all AWS infrastructure via Terraform. Lambda function **code** is deployed separately by the application CI repo (`LectureClip-App`) using `aws lambda update-function-code`; Terraform only provisions the function shells with placeholder code and uses `ignore_changes = [source_code_hash]` to avoid overwriting CI deployments.

### Terraform Modules

| Module | Resources |
|--------|-----------|
| `video_upload/networking` | VPC, public/private subnets, NAT Gateway, Lambda security group |
| `video_upload/kms` | Customer-managed KMS key for S3 and CloudWatch encryption |
| `video_upload/storage` | User videos S3 bucket (KMS-encrypted, versioned) |
| `video_upload/iam` | Lambda execution role, GitHub Actions OIDC role |
| `video_upload/lambda` | Upload Lambda function shells + Lambda artifacts S3 bucket |
| `video_upload/api_gateway` | REST API with upload endpoints (CORS-enabled) |
| `video_processing/aurora_db` | Aurora Serverless v2 PostgreSQL with pgvector extension |
| `video_processing/database` | DynamoDB table for Transcribe job state / task tokens |
| `video_processing/lambdas` | Transcription Lambdas (start-transcribe, process-transcribe) |
| `video_processing/step_function_workflow` | Step Functions state machine: S3 → Transcribe → embeddings |
| `video_processing/container` | ECS Fargate task for frame extraction and visual embeddings |
| `retrieval` | query-segments and query-segments-info Lambdas + `/query` and `/query-info` API endpoints |
| `auth` | Cognito User Pool (email-based sign-up/sign-in; outputs user_pool_id + client_id for Amplify) |
| `cicd` | GitHub Actions OIDC provider + IAM roles |
| `frontend` | AWS Amplify hosting (React/Vite SPA, branch-based deploys) |

### API Endpoints

| Method | Path | Lambda | Description |
|--------|------|--------|-------------|
| POST | `/upload` | `video-upload` | Returns presigned PUT URL (≤ 100 MB) |
| POST | `/multipart/init` | `multipart-init` | Creates multipart upload, returns presigned part URLs |
| POST | `/multipart/complete` | `multipart-complete` | Finalizes multipart upload with ETags |
| POST | `/register` | `register-user` | Upserts user in Aurora (called on every sign-in) |
| GET | `/lectures` | `list-lectures` | Returns user's lectures with presigned playback URLs |
| POST | `/query` | `query-segments` | Vector similarity search — basic segment shape |
| POST | `/query-info` | `query-segments-info` | Vector similarity search — full text + metadata |
| POST | `/chat` | `chat` | RAG chat with Claude (Bedrock) + DynamoDB sessions |

### Environments

Two isolated environments share the same AWS account but have separate Terraform state and independently-named resources:

| Environment | Branch | State key | Deploy trigger |
|-------------|--------|-----------|----------------|
| `dev` | `develop` | `lectureclip/dev/terraform.tfstate` | push to `develop` |
| `prod` | `main` | `lectureclip/prod/terraform.tfstate` | push to `main` |

All resource names follow `lectureclip-<env>-<resource>` (e.g. `lectureclip-dev-chat`).

### Remote State Backend
- **S3 bucket**: `757242163795-workshop-tf-state` (region: `ca-central-1`)
- **State keys**: `lectureclip/dev/terraform.tfstate` and `lectureclip/prod/terraform.tfstate`
- **Lock**: native S3 lock (`use_lockfile = true`, no DynamoDB needed with TF ≥ 1.6)

### Key Design Decisions
- **NAT Gateway**: Required for Lambda VPC egress to AWS APIs (~$32/month cost)
- **KMS IAM delegation**: Lambda gets KMS access through its IAM role policy, not by listing Lambda ARNs in the key policy — avoids circular dependency between `kms`, `iam`, and `lambda` modules
- **Lambda artifacts bucket**: Lives inside the `video_upload/lambda` module (not `storage`) since it's infrastructure-owned
- **Aurora access pattern**: Lambdas use the RDS Data API (HTTPS/443) — no direct TCP connection to port 5432 required in the default deployment
- **User ID derivation**: `uuid5(NAMESPACE_URL, "mailto:{email}")` is used independently by `register-user`, `list-lectures`, and `process-results` so all three agree without any explicit ID exchange
- **Terraform version**: `~>1.6` (pinned); AWS provider `~>5.0`

### CI/CD (GitHub Actions)
- **on-push.yaml**: Runs quality checks (fmt, validate, tflint, checkov) then deploys — `develop` → dev, `main` → prod.
- **on-pull-request.yaml**: Runs `terraform plan` against the target environment and posts results as a PR comment; also runs cfn-guard rules.

### Pre-commit Hooks
Configured in `.pre-commit-config.yaml`: `terraform_fmt`, `terraform_validate`, `terraform_tflint`, trailing whitespace, end-of-file fixer, YAML/JSON checks, large file detection, private key detection.

### TFLint Rules (`.config/tf-lint/.tflint.hcl`)
Enforces: snake_case naming, typed variables, documented variables/outputs, pinned module sources, standard module structure, no unused declarations.

### GitHub Actions Variables Required
- `AWS_REGION`, `AWS_ACCOUNT_ID` (repo variables)
- `AWS_ROLE_TO_ASSUME_DEV` — ARN of `lectureclip-dev-github-actions` role (repo variable)
- `AWS_ROLE_TO_ASSUME_PROD` — ARN of `lectureclip-prod-github-actions` role (repo variable)
- `GITHUB_TOKEN` (automatic)
