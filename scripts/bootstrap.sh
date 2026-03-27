#!/bin/bash

# Bootstrap Terraform backend for LectureClip
set -e

ACCOUNT_ID="757242163795"
REGION="ca-central-1"
BUCKET_NAME="${ACCOUNT_ID}-workshop-tf-state"
DYNAMODB_TABLE="terraform-state-lock"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 LectureClip Terraform Backend Bootstrap"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Account ID: ${ACCOUNT_ID}"
echo "Region:     ${REGION}"
echo "Bucket:     ${BUCKET_NAME}"
echo "DynamoDB:   ${DYNAMODB_TABLE}"
echo ""

# Create S3 bucket
echo "📦 Creating S3 bucket..."
if aws s3 mb "s3://${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
    echo "✓ Created bucket: ${BUCKET_NAME}"
else
    echo "✓ Bucket already exists: ${BUCKET_NAME}"
fi

# Enable versioning
echo "🔄 Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled \
  --region "${REGION}"
echo "✓ Versioning enabled"

# Enable encryption
echo "🔒 Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --region "${REGION}"
echo "✓ Encryption enabled"

# Block public access
echo "🚫 Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region "${REGION}"
echo "✓ Public access blocked"

# Create DynamoDB table
echo "🔐 Creating DynamoDB table for state locking..."
if aws dynamodb create-table \
  --table-name "${DYNAMODB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" \
  --tags Key=Project,Value=LectureClip Key=ManagedBy,Value=Bootstrap \
  2>/dev/null; then
    echo "✓ Created DynamoDB table: ${DYNAMODB_TABLE}"
else
    echo "✓ DynamoDB table already exists: ${DYNAMODB_TABLE}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Bootstrap Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💰 Monthly Cost: ~\$0.50 (minimal usage)"
echo ""
echo "📋 Next Steps — deploy prod first (creates the OIDC provider):"
echo ""
echo "  cd terraform"
echo ""
echo "  # Prod environment"
echo "  terraform init -backend-config=\"environments/backend-prod.hcl\""
echo "  terraform plan  -var-file=\"environments/prod.tfvars\""
echo "  terraform apply -var-file=\"environments/prod.tfvars\""
echo ""
echo "  # Dev environment (OIDC provider already exists from prod)"
echo "  terraform init -backend-config=\"environments/backend-dev.hcl\" -reconfigure"
echo "  terraform plan  -var-file=\"environments/dev.tfvars\""
echo "  terraform apply -var-file=\"environments/dev.tfvars\""
echo ""
echo "📋 GitHub Actions repo variables required:"
echo "  AWS_REGION, AWS_ACCOUNT_ID"
echo "  AWS_ROLE_TO_ASSUME_DEV   (lectureclip-dev-github-actions role ARN)"
echo "  AWS_ROLE_TO_ASSUME_PROD  (lectureclip-prod-github-actions role ARN)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
