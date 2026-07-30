#!/bin/bash
echo "Stopping sre-lab-server..."
aws ec2 stop-instances \
  --instance-ids i-0f6fd2ae096b49294 \
  --region eu-central-1 \
  --output text
echo "Server stopped."
