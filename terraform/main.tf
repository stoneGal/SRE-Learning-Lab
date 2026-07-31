terraform {
  backend "s3" {
    bucket  = "sre-lab-terraform-state-bethel"
    key     = "aws-lab/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}




provider "aws" {              # configures the AWS plugin
  region = var.aws_region    # all resources created in Frankfurt
}

resource "aws_vpc" "sre_lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "sre-lab-vpc-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}



resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.sre_lab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "sre-public-subnet-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.sre_lab.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name        = "sre-private-subnet-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}


resource "aws_internet_gateway" "sre_igw" {
  vpc_id = aws_vpc.sre_lab.id

  tags = {
    Name        = "sre-igw-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.sre_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sre_igw.id
  }

  tags = {
    Name        = "sre-public-rt-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}




resource "aws_security_group" "web" {
  name        = "sre-web-sg-terraform"
  description = "Security group for SRE lab web server"
  vpc_id      = aws_vpc.sre_lab.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sre-web-sg-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}



resource "aws_instance" "web" {
  ami                    = "ami-042dc8681de073ac4"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "sre-lab-key"

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y htop curl wget net-tools dnsutils sysstat tree vim
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/size.conf << 'JOURNAL'
    [Journal]
    SystemMaxUse=200M
    SystemKeepFree=500M
    MaxRetentionSec=7day
    JOURNAL
    systemctl restart systemd-journald
  EOF

  tags = {
    Name        = "sre-lab-server-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}


resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name        = "sre-lab-eip"
    Environment = var.environment
    Owner       = var.owner
  }
}

