import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

INSTANCE_ID = os.environ["EC2_INSTANCE_ID"]
SNS_TOPIC = os.environ["SNS_TOPIC_ARN"]

def lambda_handler(event, context):
    logger.info(f"Alert received, rebooting {INSTANCE_ID}")
    ec2.reboot_instances(InstanceIds=[INSTANCE_ID])

    sns.publish(
        TopicArn=SNS_TOPIC,
        Subject="Auto-Remediation: EC2 Rebooted",
        Message=f"Instance {INSTANCE_ID} was automatically rebooted due to elevated /api/data response times (>3s threshold breached)."
    )

    logger.info("Remediation complete, notification sent")
    return {"statusCode": 200, "body": "Remediation complete"}


lambda function .py
