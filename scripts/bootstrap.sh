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
if aws storage mb "s3://${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
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
echo "📋 Next Steps:"
echo ""
echo "  1. cd terraform"
echo "  2. terraform init"
echo "  3. terraform plan"
echo "  4. terraform apply"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
