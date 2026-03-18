# Platform Engineer Coding Test — Auto-Remediation Pipeline

## Overview

I built an automated monitoring and remediation solution for a web application experiencing intermittent performance issues on the `/api/data` endpoint.

**Pipeline Flow:** Sumo Logic (monitoring) → Lambda (remediation) → SNS (notification)

When the `/api/data` endpoint response time exceeds 3 seconds more than 5 times in a 10-minute window, the system automatically reboots the affected EC2 instance and notifies the engineering team.

## Repository Structure

| Folder | File | Description |
|--------|------|-------------|
| sumo_logic/ | sumo_logic_query.txt | Sumo Logic query and alert config |
| lambda_function/ | lambda_function.py | Python Lambda function |
| terraform/ | main.tf | Infrastructure as Code |
| / | README.md | Documentation |

## Part 1: Sumo Logic Query

I wrote a query that monitors production web server logs and filters for `/api/data` requests exceeding a 3-second response time. I grouped results into 10-minute windows and set it to only trigger when more than 5 slow requests are detected. This way we avoid false alarms from random one-off spikes.

For the alert, I would set this up as a Sumo Logic Monitor running every 5 minutes with a webhook notification pointing to my Lambda Function URL.

## Part 2: AWS Lambda Function

My Lambda function does three things when triggered:

- Reboots the EC2 instance using boto3
- Sends a notification to SNS so the team knows what happened
- Logs everything to CloudWatch for debugging

I chose reboot over stop/start because reboot keeps the same public IP address, which avoids breaking any downstream services.

I used environment variables for the instance ID and SNS topic instead of hardcoding them. Terraform injects these automatically during deployment, keeping the code clean and portable.

## Part 3: Terraform Infrastructure

I wrote a single Terraform file that deploys everything in one apply:

- EC2 instance (the web server being monitored)
- SNS topic (for alert notifications)
- Lambda function (auto-zipped from my Python source)
- Lambda Function URL (the webhook endpoint for Sumo Logic)
- IAM role with least privilege permissions

### Least Privilege IAM

I was deliberate about keeping permissions tight:

- ec2:RebootInstances — scoped to just this one EC2 instance
- sns:Publish — scoped to just this one SNS topic
- CloudWatch Logs — standard logging that every Lambda needs

So even if this Lambda was somehow compromised, the blast radius is minimal.

## Assumptions and Notes

- I assumed logs are in JSON format under _sourceCategory=prod/web/access
- I hardcoded the AMI ID for us-east-1; in production I would use a data source for dynamic lookup
- I used a Function URL instead of API Gateway for simplicity; in production I would add webhook signature validation
- I validated the Terraform config with terraform init; full deployment requires AWS credentials
- In a production setup, I would also add a cooldown mechanism to prevent repeated reboots in quick succession

## Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

After deployment, copy the webhook_url output and configure it as the Sumo Logic Monitor webhook endpoint.
