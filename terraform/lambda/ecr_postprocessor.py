import json, os, boto3
from datetime import datetime

ddb = boto3.client('dynamodb')
sns = boto3.client('sns')

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    # Read repository & tag from EventBridge custom event
    detail = event.get('detail', {})
    repo = detail.get('repository', 'unknown')
    tag = detail.get('imageTag', 'unknown')

    ts = datetime.utcnow().isoformat()

    # Log to DynamoDB
    ddb.put_item(
        TableName=os.environ['DDB_TABLE'],
        Item={
            'imageTag': {'S': tag},
            'repository': {'S': repo},
            'timestamp': {'S': ts}
        }
    )

    # Send SNS notification
    sns.publish(
        TopicArn=os.environ['SNS_ARN'],
        Message=f"Image pushed: {repo}:{tag} at {ts}",
        Subject="ECR Image Push Notification"
    )

    return {'status': 'ok'}
