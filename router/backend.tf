# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "s3" {
    bucket  = "tf-state-43mar.io"
    encrypt = true
    key     = "components/router/terraform.tfstate"
    region  = "us-east-1"
  }
}
