terraform {
  backend "s3" {
    bucket         = "sre-lab-terraform-state-bethel"
    key            = "aws-lab/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "sre-lab-terraform-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}




provider "aws" {          # configures the AWS plugin
  region = var.aws_region # all resources created in Frankfurt
}

resource "aws_iam_role" "ec2_ecr_pull" {
  name = "sre-lab-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_pull_attach" {
  role       = aws_iam_role.ec2_ecr_pull.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_ecr_pull_profile" {
  name = "sre-lab-ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr_pull.name
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
    cidr_blocks = ["95.91.213.49/32"]
  }

  ingress {
    description     = "HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Container HTTP"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["95.91.213.49/32"]
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

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  ami                    = "ami-042dc8681de073ac4"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "sre-lab-key"
  iam_instance_profile   = aws_iam_instance_profile.ec2_ecr_pull_profile.name

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
  validation_method         = "DNS"

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
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "web_https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.web.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 8080
}



resource "aws_dynamodb_table" "terraform_locks" {
  name         = "sre-lab-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "sre-lab-terraform-locks"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_ecr_repository" "my_nginx_site" {
  name                 = "my-nginx-site"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

resource "aws_iam_role" "github_actions" {
  name = "sre-lab-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:stoneGal/SRE-Learning-Lab:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}




resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ecr_pull.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "github_actions_ssm_deploy" {
  name = "sre-lab-github-actions-ssm-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:SendCommand"
        Resource = [
          aws_instance.web.arn,
          "arn:aws:ssm:eu-central-1::document/AWS-RunShellScript"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "k3s" {
  name        = "sre-lab-k3s-sg"
  description = "Security group for k3s practice server"
  vpc_id      = aws_vpc.sre_lab.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["95.91.213.49/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sre-lab-k3s-sg"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_instance" "k3s" {
  ami                         = "ami-042dc8681de073ac4"
  instance_type               = "c7i-flex.large"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  key_name                    = "sre-lab-key"
  iam_instance_profile        = aws_iam_instance_profile.ec2_ecr_pull_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "sre-lab-k3s"
    Environment = var.environment
    Owner       = var.owner
  }
}

output "k3s_public_ip" {
  value = aws_instance.k3s.public_ip
}
