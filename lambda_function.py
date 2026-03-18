import json
import os
import boto3

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

INSTANCE_ID = os.environ["EC2_INSTANCE_ID"]
SNS_TOPIC = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):
    # 1. Restart the EC2 instance
    ec2.reboot_instances(InstanceIds=[INSTANCE_ID])
    print(f"Rebooted instance {INSTANCE_ID}")

    # 2. Send notification
    sns.publish(
        TopicArn=SNS_TOPIC,
        Subject="EC2 Auto-Reboot Triggered",
        Message=f"Instance {INSTANCE_ID} was rebooted due to slow /api/data responses."
    )
    print("SNS notification sent")

    # 3. Return success
    return {"statusCode": 200, "body": "Remediation complete"}
