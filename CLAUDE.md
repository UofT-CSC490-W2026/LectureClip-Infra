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
terraform output      # View all outputs (API endpoints, KMS key ID)
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
LectureClip is a video upload platform. This repo provisions all AWS infrastructure via Terraform. Lambda function **code** is deployed separately by the application CI repo (`LectureClip-App`) using `aws lambda update-function-code`; Terraform only provisions the function shells with placeholder code and uses `ignore_changes = [source_code_hash]` to avoid overwriting CI deployments.

### API Endpoints (outputs)
- `POST /uploads` — generates a pre-signed PUT URL for direct single-file upload
- `POST /multipart/init` — initializes a multipart upload, returns pre-signed part URLs
- `POST /multipart/complete` — assembles uploaded parts into a final S3 object

### Environments
Two isolated environments share the same AWS account but have separate Terraform state and independently-named resources:

| Environment | Branch   | State key                       | Deploy trigger        |
|-------------|----------|---------------------------------|-----------------------|
| `dev`       | develop  | `lectureclip/dev/terraform.tfstate`  | push to `develop`     |
| `prod`      | main     | `lectureclip/prod/terraform.tfstate` | push to `main`        |

All resource names follow `lectureclip-<env>-<resource>` (e.g., `lectureclip-dev-video-upload`).

### Remote State Backend
- **S3 bucket**: `757242163795-workshop-tf-state` (region: `ca-central-1`)
- **State keys**: `lectureclip/dev/terraform.tfstate` and `lectureclip/prod/terraform.tfstate`
- **Lock**: native S3 lock (`use_lockfile = true`, no DynamoDB needed with TF ≥ 1.6)

### Key Design Decisions
- **NAT Gateway**: Required for Lambda VPC egress to AWS APIs (~$32/month cost)
- **KMS IAM delegation**: Lambda gets KMS access through its IAM role policy, not by listing Lambda ARNs in the key policy — avoids circular dependency between `kms`, `iam`, and `lambda` modules
- **Lambda artifacts bucket**: Lives inside the `lambda` module (not `storage`) since it's infrastructure-owned
- **Terraform version**: `~>1.6` (pinned); AWS provider `~>5.0`

### CI/CD (GitHub Actions)
- **on-push.yaml**: Runs quality checks (fmt, validate, tflint, checkov) then deploys — `develop` → dev, `main` → prod.
- **on-pull-request.yaml**: Runs `terraform plan` against prod state and posts results as a PR comment; also runs cfn-guard rules.

### Pre-commit Hooks
Configured in `.pre-commit-config.yaml`: `terraform_fmt`, `terraform_validate`, `terraform_tflint`, trailing whitespace, end-of-file fixer, YAML/JSON checks, large file detection, private key detection.

### TFLint Rules (`.config/tf-lint/.tflint.hcl`)
Enforces: snake_case naming, typed variables, documented variables/outputs, pinned module sources, standard module structure, no unused declarations.

### GitHub Actions Variables Required
- `AWS_REGION`, `AWS_ACCOUNT_ID` (repo variables)
- `AWS_ROLE_TO_ASSUME_DEV` — ARN of `lectureclip-dev-github-actions` role (repo variable)
- `AWS_ROLE_TO_ASSUME_PROD` — ARN of `lectureclip-prod-github-actions` role (repo variable)
- `GITHUB_TOKEN` (automatic)
