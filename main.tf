module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.stack_name
  cidr = "10.200.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.200.101.0/24", "10.200.102.0/24"]

  enable_nat_gateway = false
  map_public_ip_on_launch = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_iam_policy_attachment" "ssm_core" {
  name       = "${var.stack_name}-ssm-core"
  roles      = [aws_iam_role.web.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy_attachment" "ssm_role" {
  name       = "${var.stack_name}-ssm-role"
  roles      = [aws_iam_role.web.id]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# Create web security group
resource "aws_security_group" "web" {
  name        = "${var.stack_name}-web-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

resource "aws_security_group_rule" "allow_http" {
  description = "allow http"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_http_cidrs]
  security_group_id = aws_security_group.web.id
}

# Create webserver
data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id = module.vpc.public_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.web.id
  vpc_security_group_ids = [ aws_security_group.web.id ]
  user_data = file("bootstrap.sh")

  tags = {
    Name = "${var.stack_name}-webserver"
    Purpose = "web"
  }
}

resource "aws_eip" "web" {
  instance = aws_instance.web.id
}