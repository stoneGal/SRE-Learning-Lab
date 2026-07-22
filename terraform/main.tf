terraform {
  required_providers {        # tells Terraform which plugins to download
    aws = {
      source  = "hashicorp/aws"  # official AWS plugin from HashiCorp
      version = "~> 5.0"         # use version 5.x (~ means flexible patch)
    }
  }
}




provider "aws" {              # configures the AWS plugin
  region = "eu-central-1"    # all resources created in Frankfurt
}

resource "aws_vpc" "sre_lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "sre-lab-vpc-terraform"
    Environment = "learning"
    Owner       = "bethel"
  }
}



resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.sre_lab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "sre-public-subnet-terraform"
    Environment = "learning"
    Owner       = "bethel"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.sre_lab.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name        = "sre-private-subnet-terraform"
    Environment = "learning"
    Owner       = "bethel"
  }
}


resource "aws_internet_gateway" "sre_igw" {
  vpc_id = aws_vpc.sre_lab.id

  tags = {
    Name        = "sre-igw-terraform"
    Environment = "learning"
    Owner       = "bethel"
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
    Environment = "learning"
    Owner       = "bethel"
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
    Environment = "learning"
    Owner       = "bethel"
  }
}










resource "aws_instance" "web" {
  ami                    = "ami-042dc8681de073ac4"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "sre-lab-key"

  tags = {
    Name        = "sre-lab-server-terraform"
    Environment = "learning"
    Owner       = "bethel"
  }
}
