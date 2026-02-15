provider "aws" {
  region = "ca-central-1" # Changed from us-east-1

  default_tags {
    tags = {
      Project    = "LectureClip"
      ManagedBy  = "Terraform"
      Repository = "UofT-CSC490-W2026/LectureClip-Infra"
    }
  }
}

provider "awscc" {
  region = "ca-central-1" # Changed from us-east-1
}
