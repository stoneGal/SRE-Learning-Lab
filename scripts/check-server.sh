#!/bin/bash
aws ec2 describe-instances --instance-ids i-02eb8f305293707ba --region eu-central-1 --query 'Reservations[0].Instances[0].State.Name' --output text
