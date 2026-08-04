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

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.sre_lab.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "sre-public-b-subnet-terraform"
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


resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
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
    security_groups = [aws_security_group.alb.id]
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
    apt install -y nginx htop curl wget net-tools dnsutils sysstat tree vim
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


resource "aws_security_group" "alb" {
  name        = "sre-lab-alb-sg-terraform"
  description = "Security group for SRE lab ALB"
  vpc_id      = aws_vpc.sre_lab.id

  
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
    Name        = "sre-lab-alb-sg-terraform"
    Environment = var.environment
    Owner       = var.owner
  }
}


resource "aws_lb" "web" {
  name               = "sre-lab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]

  tags = {
    Name        = "sre-lab-alb"
    Environment = var.environment
    Owner       = var.owner
  }
}

data "aws_route53_zone" "main" {
  name = "bethel-sre-lab.online"
}


resource "aws_acm_certificate" "web" {
  domain_name               = "bethel-sre-lab.online"
  subject_alternative_names = ["*.bethel-sre-lab.online"]
  validation_method          = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "sre-lab-cert"
    Environment = var.environment
    Owner       = var.owner
  }
}



resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.web.domain_validation_options : dvo.resource_record_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }...
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value[0].name
  type    = each.value[0].type
  records = [each.value[0].record]
  ttl     = 60
}


resource "aws_acm_certificate_validation" "web" {
  certificate_arn         = aws_acm_certificate.web.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


resource "aws_lb_target_group" "web" {
  name     = "sre-lab-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sre_lab.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name        = "sre-lab-tg"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 80
}








