terraform {
  required_version = ">= 1.7.0"
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dr"
  region = "us-east-1"
}
