terraform {
  backend "s3" {
    bucket         = "terraorbit-tfstate-49b88bb9"
    key            = "terraorbit/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraorbit-tf-locks"
    encrypt        = true
  }
}
