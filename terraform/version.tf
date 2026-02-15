terraform {
  backend "s3" {
    bucket       = "757242163795-workshop-tf-state"
    key          = "lectureclip/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = "terraform-state-lock"
  }

  required_version = "~>1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~>1.0"
    }
  }
}
