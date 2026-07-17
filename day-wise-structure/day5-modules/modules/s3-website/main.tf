terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "assets" {
  bucket = "${var.name_prefix}-assets-${random_id.bucket_suffix.hex}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "dr_backup" {
  provider = aws.dr
  bucket   = "${var.name_prefix}-dr-backup-${random_id.bucket_suffix.hex}"
  tags     = var.common_tags
}
