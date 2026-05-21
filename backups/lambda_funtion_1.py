import json
import urllib.parse

def handler(event, context):
    try:
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
        
        print("SUCCESS: New file detected!")
        print("Bucket: " + str(bucket))
        print("File: " + str(key))
        
        return {
            "statusCode": 200,
            "body": json.dumps("File logged successfully")
        }
    except Exception as e:
        print("Error: " + str(e))
        raise e
