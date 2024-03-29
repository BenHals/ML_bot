import json
import logging
import os
from enum import Enum
from typing import Any

import boto3
import nacl
import nacl.exceptions
import nacl.signing

logger = logging.getLogger(__name__)

PUBLIC_KEY = os.environ.get("DISCORD_PUBLIC_KEY")

class ResponseTypes(Enum):
    PING_RESPONSE = 1
    ACK_NO_SOURCE = 2
    MESSAGE_NO_SOURCE = 3
    MESSAGE_WITH_SOURCE = 4
    DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE = 5

Response = dict[str, Any]

def verify_signature(event: dict[str, Any]) -> tuple[bool, Exception | None]:
    raw_body = event.get("body").encode().decode('utf-8')
    signature = event["headers"]["x-signature-ed25519"]
    timestamp = event["headers"]["x-signature-timestamp"]
    verify_key = nacl.signing.VerifyKey(bytes.fromhex(PUBLIC_KEY))

    logger.warning(PUBLIC_KEY)
    logger.warning(signature)
    logger.warning(timestamp)
    logger.warning(raw_body)
    message = f"{timestamp}{raw_body}".encode()
    logger.warning(message)
    try:
        verify_key.verify(message, bytes.fromhex(signature))
    except Exception as e:
        return False, e

    return True, None

def handle_ping() -> Response:
    return {
        'statusCode': 200,
        'body': json.dumps({
            "type": ResponseTypes.PING_RESPONSE.value
        })
    } 

def _build_reponse(content: dict[str, Any], type: ResponseTypes) -> Response:
    response = {
        'body': json.dumps({
            "type": type.value,
            "data": content,
        }),
        'statusCode': 200
    }
    return response


def handle_command(body: dict[str, Any]) -> Response:
    command = body['data']['name']
    if command == 'test_resp':
        response = _build_reponse({
            "content": "Bot working :)"
        }, ResponseTypes.MESSAGE_WITH_SOURCE)
        return response
    elif command == "slow_test":
        interaction_token = body['token']
        lambda_client = boto3.client('lambda')
        lambda_client.invoke(
            FunctionName='test_slow_command_lambda',
            InvocationType='Event',
            Payload=json.dumps({
                'interaction_token': interaction_token
            })
        )
        response = _build_reponse({
            "content": "LOADING"
        }, ResponseTypes.DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE)
        return response
    else:
        raise ValueError("Invalid Command")

def lambda_handler(event, context) -> Response:
    logger.warning(event)
    logger.warning(context)
    verified, verify_exception = verify_signature(event)
    if not verified and verify_exception is not None:
        raise Exception(f"Auth Exception {verify_exception}")

    body = json.loads(event.get('body'))
    if body.get("type") == 1:
        response: Response = handle_ping() 
    else:
        response = handle_command(body)

    logger.warning(response)
    return response
