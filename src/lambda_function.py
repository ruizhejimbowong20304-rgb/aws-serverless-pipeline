import json
import urllib.parse
import boto3
import os
from datetime import datetime, timezone

# Initialize the AWS SDK client
sns_client = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    try:
        
        # Pull the ARN from the Lambda Environment Variable we set in Terraform
        sns_topic_arn = os.environ['SNS_TOPIC_ARN']
        table_name = os.environ['DYNAMODB_TABLE']
        
        # Connect to the specific DynamoDB talbe
        table = dynamodb.Table(table_name)
        
        # Extract bucket and file details from the S3 trigger event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
        
        # Generate a clean UTC timestamp
        timestamp = datetime.now(timezone.utc).isoformat()

        # Write the record to DynamoDB (This uses the dynamodb:PutItem permission)
        table.put_item(
            Item={
                 'FileID': key, # This MUST match the hash_key defined in main.tf
                 'BucketName': bucket,
                 'UploadTime': timestamp
            }
        )
        print(f"SUCCESS: Database record created for {key}")

        # Construct the alert (This uses the sns:Publish permission)
        subject = "Lab Alert: S3 Upload Detected and DB Log Detected"
        message = f"Success! The file '{key}' was uploaded to '{bucket}' and logged in the database at '{timestamp}'."
        
        # Send the notification email
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=message
        )
        
        print(f"SUCCESS: Alert sent for {key}")
        
        return {
            "statusCode": 200,
            "body": json.dumps("Notificati sent successfully")
        }
    except Exception as e:
        print("Error: " + str(e))
        raise e
