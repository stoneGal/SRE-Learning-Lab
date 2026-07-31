#!/bin/bash
echo "Starting sre-lab-server..."
aws ec2 start-instances \
  --instance-ids i-02eb8f305293707ba \
  --region eu-central-1 \
  --output text
echo "Done. SSH with: ssh sre-lab"
