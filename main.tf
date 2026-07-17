data "aws_caller_identity" "current" {}

module "network" {
  source               = "./modules/network"
  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  common_tags          = local.common_tags
}

module "compute" {
  source            = "./modules/compute"
  name_prefix       = local.name_prefix
  instance_type     = var.instance_type
  subnet_id         = module.network.public_subnet_ids[0]
  security_group_id = module.network.web_sg_id
  common_tags       = local.common_tags
}

module "s3_website" {
  source      = "./modules/s3-website"
  name_prefix = local.name_prefix
  common_tags = local.common_tags
}
