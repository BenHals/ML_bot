import os

import nacl

PUBLIC_KEY = os.environ.get("DISCORD_PUBLIC_KEY")

def lambda_handler(event, context):
    result = f"Hello world {str(nacl)} {PUBLIC_KEY}"
    return {
        'statusCode': 200,
        'body': result
    }
