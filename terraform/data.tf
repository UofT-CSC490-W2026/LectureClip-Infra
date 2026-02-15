# ============================================================================
# DATA SOURCES
# Fetch information from AWS without creating resources
# ============================================================================

# Get current AWS account information
data "aws_caller_identity" "current" {}

# Identify current AWS partition (e.g., aws, aws-cn)
data "aws_partition" "current" {}

# Discover the region configured on the provider
data "aws_region" "current" {}
