terraform {
  required_version = ">= 1.7.0"
}

provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "dr"
  region = "us-east-1"
}
