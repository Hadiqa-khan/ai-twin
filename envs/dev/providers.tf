provider "aws" {
  region = "us-east-1"
  # No profile here: locally AWS_PROFILE=hk is used, in CI the OIDC role is used
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Variant   = "human"
    }
  }
}
