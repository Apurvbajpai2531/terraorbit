
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "web_public_ip" {
  value = module.compute.instance_public_ip
}


output "assets_bucket" {
  value = module.s3_website.bucket_name
}
