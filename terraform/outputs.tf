output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.sre_lab.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "ssh_command" {
  description = "Command to SSH into the server"
  value       = "ssh -i ~/.ssh/sre-lab-key.pem ubuntu@${aws_instance.web.public_ip}"
}

output "elastic_ip" {
  description = "Elastic IP address - never changes"
  value       = aws_eip.web.public_ip
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}