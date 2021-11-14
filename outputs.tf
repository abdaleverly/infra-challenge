output "public_subnets" {
  value = module.vpc.public_subnets
}

output "web_endpoint" {
  value = "http://${aws_eip.web.public_dns}"
}