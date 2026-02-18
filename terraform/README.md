# Terraform New Structure - AWS Best Practices

This directory contains the restructured Terraform configuration following AWS best practices for Terraform project organization.

## Directory Structure

```
terraform-new/
├── main.tf                 # Root module - orchestrates all modules
├── variables.tf            # Root-level variable definitions
├── outputs.tf              # Root-level outputs
├── terraform.tfvars        # Variable values (customize per environment)
│
├── modules/               # Reusable Terraform modules
│   ├── s3/               # S3 bucket resources
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── iam/              # IAM roles and policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── lambda/           # Lambda functions
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── lambda_code/  # Lambda source code
│   │       ├── index.py
│   │       └── video_upload.zip
│   │
│   └── api_gateway/      # API Gateway resources
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── config/               # Configuration files (future use)
```

## Architecture

The infrastructure is organized into four main modules:

1. **S3 Module** - Manages S3 buckets for video storage with encryption, versioning, and SNS notifications
2. **IAM Module** - Manages IAM roles and policies for Lambda and GitHub Actions
3. **Lambda Module** - Manages Lambda functions for video upload processing
4. **API Gateway Module** - Manages REST API endpoints for video uploads

## Key Differences from Old Structure

### Old Structure (Flat)
- All resources in a single directory
- Resources grouped by AWS service in separate files
- Tight coupling between resources
- Harder to reuse components

### New Structure (Modular)
- Resources organized into reusable modules
- Each module is self-contained with inputs/outputs
- Clear dependencies between modules
- Easy to add/remove/modify individual components
- Follows AWS best practices for Terraform

## Module Dependencies

```
┌─────────────┐
│ Root Module │
└──────┬──────┘
       │
       ├──> S3 Module ──────┐
       │                    │
       ├──> IAM Module ◄────┤ (depends on S3)
       │         │          │
       ├──> Lambda Module ◄─┤ (depends on IAM & S3)
       │         │
       └──> API Gateway ◄───┘ (depends on Lambda)
```

## Usage

### Initialize Terraform
```bash
cd terraform
terraform init
```

### Plan Changes
```bash
terraform plan
```

### Apply Infrastructure
```bash
terraform apply
```

### Get Outputs
```bash
terraform output
terraform output video_upload_api_url
```

### Destroy Infrastructure
```bash
terraform destroy
```

## Customization

### Modify Variables
Edit `terraform.tfvars` to customize:
- AWS region
- Project name
- Environment name

### Add New Modules
1. Create a new directory under `modules/`
2. Add `main.tf`, `variables.tf`, and `outputs.tf`
3. Reference the module in root `main.tf`

## Benefits of This Structure

✅ **Modularity** - Each module can be developed and tested independently
✅ **Reusability** - Modules can be reused across different environments
✅ **Maintainability** - Changes to one module don't affect others
✅ **Scalability** - Easy to add new modules as infrastructure grows
✅ **Clear Dependencies** - Module inputs/outputs make dependencies explicit
✅ **Best Practices** - Follows AWS recommendations for Terraform structure
✅ **Version Control** - Easier to track changes per module

## Migration from Old Structure

To migrate from the old `terraform/` directory:

1. **Test the new structure:**
   ```bash
   cd terraform
   terraform init
   terraform plan
   ```

2. **Compare state:**
   ```bash
   # The resources should be the same, just organized differently
   terraform plan  # Should show no changes if modules are equivalent
   ```

3. **Apply if satisfied:**
   ```bash
   terraform apply
   ```

4. **Archive old directory:**
   ```bash
   mv ../terraform ../terraform-old
   mv ../terraform ../terraform
   ```

## Module Details

### S3 Module
- User videos bucket with encryption
- Versioning enabled
- Public access blocked
- SNS topic for S3 events

### IAM Module
- GitHub Actions OIDC provider and role
- Lambda execution role
- S3 access policies

### Lambda Module
- Video upload Lambda function
- CloudWatch log group
- Environment variables

### API Gateway Module
- REST API Gateway
- POST /upload endpoint
- CORS configuration
- Lambda integration

## Next Steps

1. Review module configurations
2. Customize `terraform.tfvars` for your environment
3. Initialize and plan with `terraform init && terraform plan`
4. Apply infrastructure with `terraform apply`
5. Test API endpoint: `curl $(terraform output -raw video_upload_api_url)`

## Additional Resources

- [AWS Terraform Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html)
- [Terraform Module Documentation](https://www.terraform.io/docs/language/modules/develop/index.html)
