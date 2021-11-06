module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "challenge"
  cidr = "10.200.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.200.101.0/24", "10.200.102.0/24"]

  enable_nat_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}