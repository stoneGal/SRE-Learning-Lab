#!/bin/bash
echo "Stopping sre-lab-server..."
aws ec2 stop-instances \
  --instance-ids i-02eb8f305293707ba \
  --region eu-central-1 \
  --output text
echo "Server stopped."
