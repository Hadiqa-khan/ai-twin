provider "aws" {
  region = "ap-southeast-2"
  # No profile here: locally AWS_PROFILE=hk is used, in CI the OIDC role is used
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Variant   = "human"
    }
  }
}
