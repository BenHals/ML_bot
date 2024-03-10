import boto3

print(boto3)

def lambda_handler(event, context):
    result = "Hello world"
    return {
        'statusCode': 200,
        'body': result
    }
