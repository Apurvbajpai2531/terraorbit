locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Challenge   = "TerraWeek"
  }, var.extra_tags)

  name_prefix = "${var.project_name}-${terraform.workspace}"
  is_prod     = var.environment == "prod" ? true : false
}
