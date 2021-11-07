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

# Create role for ec2 instance
resource "aws_iam_instance_profile" "web" {
  name = "webserver"
  role = aws_iam_role.web.name
}

resource "aws_iam_role" "web" {
  name = "webserver_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "ssm_core" {
  name       = "ssm_core"
  roles      = [aws_iam_role.web.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy_attachment" "ssm_role" {
  name       = "ssm_role"
  roles      = [aws_iam_role.web.id]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# Create web security group
resource "aws_security_group" "web" {
  name        = "web-sg"
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
  cidr_blocks       = [var.allowed_cidrs]
  security_group_id = aws_security_group.web.id
}

# Create webserver
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id = module.vpc.public_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.web.id
  vpc_security_group_ids = [ aws_security_group.web.id ]

  tags = {
    Name = "challenge-webserver"
  }
}