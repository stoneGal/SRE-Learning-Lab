#!/bin/bash
echo "Starting sre-lab-server..."
aws ec2 start-instances \
  --instance-ids i-0f6fd2ae096b49294 \
  --region eu-central-1 \
  --output text
echo "Done. SSH with: ssh sre-lab"
