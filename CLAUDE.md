# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Setup
```bash
make install          # Install all prerequisites (terraform, tflint, cfn-lint, cfn-guard, checkov, pre-commit)
scripts/bootstrap.sh  # Bootstrap the S3 + DynamoDB Terraform backend (run once)
```

### Terraform Workflow
All commands run from `terraform/`:
```bash
terraform init        # Initialize with remote S3 backend
terraform init -backend=false  # Init without backend (for CI validation)
terraform plan
terraform apply
terraform destroy
terraform output      # View all outputs (API endpoints, KMS key ID)
terraform fmt -recursive  # Auto-format all .tf files
terraform validate
```

### Linting & Security
```bash
tflint --config .config/tf-lint/.tflint.hcl  # Run from terraform/ directory
checkov -d terraform/ --framework terraform
pre-commit run --all-files  # Run all pre-commit hooks
```

## Architecture

### Infrastructure Overview
LectureClip is a video upload platform. This repo provisions all AWS infrastructure via Terraform. Lambda function **code** is deployed separately by the application CI repo (`LectureClip-App`) using `aws lambda update-function-code`; Terraform only provisions the function shells with placeholder code and uses `ignore_changes = [source_code_hash]` to avoid overwriting CI deployments.

### Module Dependency Graph
```
Root Module (terraform/main.tf)
├── kms       — Customer-managed KMS key for S3 + CloudWatch encryption
├── networking — VPC with public/private subnets, NAT Gateway, Lambda security group
├── storage    — User videos S3 bucket (KMS-encrypted, depends on kms)
├── iam        — Lambda execution role + GitHub Actions OIDC role (depends on kms, storage)
├── lambda     — 3 Lambda functions + Lambda artifacts S3 bucket (depends on iam, storage, networking)
└── api_gateway — REST API with 3 endpoints (depends on lambda)
```

### API Endpoints (outputs)
- `POST /uploads` — generates a pre-signed PUT URL for direct single-file upload
- `POST /multipart/init` — initializes a multipart upload, returns pre-signed part URLs
- `POST /multipart/complete` — assembles uploaded parts into a final S3 object

### Remote State Backend
- **S3 bucket**: `757242163795-workshop-tf-state` (region: `ca-central-1`)
- **State key**: `lectureclip/terraform.tfstate`
- **Lock**: native S3 lock (`use_lockfile = true`, no DynamoDB needed with TF ≥ 1.6)

### Key Design Decisions
- **NAT Gateway**: Required for Lambda VPC egress to AWS APIs (~$32/month cost)
- **KMS IAM delegation**: Lambda gets KMS access through its IAM role policy, not by listing Lambda ARNs in the key policy — avoids circular dependency between `kms`, `iam`, and `lambda` modules
- **Lambda artifacts bucket**: Lives inside the `lambda` module (not `storage`) since it's infrastructure-owned
- **Terraform version**: `~>1.6` (pinned); AWS provider `~>5.0`

### CI/CD (GitHub Actions)
- **on-push.yaml**: Runs on pushes to `main`/`develop` — terraform fmt check, validate, tflint, checkov security scan, YAML/markdown lint
- **on-pull-request.yaml**: Runs `terraform plan` with AWS OIDC auth and posts results as PR comments; also runs cfn-guard rules. Contains placeholder sections meant to be completed as part of a workshop.

### Pre-commit Hooks
Configured in `.pre-commit-config.yaml`: `terraform_fmt`, `terraform_validate`, `terraform_tflint`, trailing whitespace, end-of-file fixer, YAML/JSON checks, large file detection, private key detection.

### TFLint Rules (`.config/tf-lint/.tflint.hcl`)
Enforces: snake_case naming, typed variables, documented variables/outputs, pinned module sources, standard module structure, no unused declarations.

### GitHub Actions Variables Required
- `AWS_REGION`, `AWS_ACCOUNT_ID`, `AWS_ROLE_TO_ASSUME` (repo variables)
- `GITHUB_TOKEN` (automatic)
