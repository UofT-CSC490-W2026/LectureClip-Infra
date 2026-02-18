# LectureClip Infrastructure

AWS infrastructure for the LectureClip platform, provisioned with Terraform. This repo manages all cloud resources — networking, storage, compute, and API — for the video upload pipeline.

Lambda function **code** is owned and deployed by the application CI repo (`LectureClip-App`) via `aws lambda update-function-code`. Terraform provisions the function shells and does not overwrite application deployments.

### Terraform Modules

| Module | Resources |
|---|---|
| `networking` | VPC, public/private subnets, NAT Gateway, Lambda security group |
| `kms` | Customer-managed key for S3 and CloudWatch encryption |
| `storage` | User videos S3 bucket (KMS-encrypted, versioned) |
| `iam` | Lambda execution role, GitHub Actions OIDC role |
| `lambda` | 3 Lambda functions + Lambda artifacts S3 bucket |
| `api_gateway` | REST API with 3 endpoints (CORS-enabled) |

### API Endpoints

| Method | Path | Lambda | Description |
|---|---|---|---|
| POST | `/uploads` | `video-upload` | Returns a pre-signed PUT URL for direct upload |
| POST | `/multipart/init` | `multipart-init` | Creates a multipart upload, returns pre-signed part URLs |
| POST | `/multipart/complete` | `multipart-complete` | Assembles uploaded parts into a final S3 object |

## Repository Structure

```
.
├── terraform/
│   ├── main.tf             # Root module — wires all modules together
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars    # Environment values (region, project name, etc.)
│   └── modules/
│       ├── networking/
│       ├── kms/
│       ├── storage/
│       ├── iam/
│       ├── lambda/
│       └── api_gateway/
├── scripts/
│   └── bootstrap.sh        # One-time setup: creates S3 backend bucket + DynamoDB lock table
├── .config/
│   ├── tf-lint/.tflint.hcl # TFLint rules
│   └── cfn-guard/          # cfn-guard rules
├── .github/workflows/
│   ├── on-push.yaml        # Format check, validate, lint, security scan
│   └── on-pull-request.yaml
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
If using AWS SSO, run:

```bash
aws sso login --profile <your-profile-name>
export AWS_PROFILE=<your-profile-name>
```

### 3. Bootstrap the remote backend

Run for the first time only once to create the S3 bucket and enable state locking used by the Terraform backend:

```bash
bash scripts/bootstrap.sh
```

This creates:
- S3 bucket `757242163795-workshop-tf-state` (versioned, encrypted, public access blocked)
- DynamoDB table `terraform-state-lock` (used for locking with older Terraform; native S3 locking is enabled)

### 4. Initialize and deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 5. Get API endpoint URLs

```bash
terraform output uploads_endpoint
terraform output multipart_init_endpoint
terraform output multipart_complete_endpoint
```

## Deploying Changes

### Modifying existing infrastructure

Edit the relevant module under `terraform/modules/`, then:

```bash
cd terraform
terraform plan   # Review changes
terraform apply
```

### Adding a new module

1. Create `terraform/modules/<name>/main.tf`, `variables.tf`, `outputs.tf`
2. Add the module block to `terraform/main.tf`
3. Pass outputs to dependent modules as needed

### Updating Lambda code

Lambda code is managed by the application. Refer to the `LectureClip-App` repository for deployment instructions.

## CI/CD

### GitHub Actions variables required

Set these in the repository's **Variables**:

| Variable | Description |
|---|---|
| `AWS_REGION` | Target AWS region (e.g. `ca-central-1`) |
| `AWS_ACCOUNT_ID` | AWS account ID |
| `AWS_ROLE_TO_ASSUME` | IAM role ARN for OIDC-based auth |

### Workflows

**on-push** (pushes to `main`/`develop`): Terraform format check, validate, tflint, YAML/Markdown lint.

## Remote State

- **Backend**: S3
- **Bucket**: `757242163795-workshop-tf-state`
- **Key**: `lectureclip/terraform.tfstate`
- **Region**: `ca-central-1`
- **Locking**: Native S3 lock (`use_lockfile = true`)
