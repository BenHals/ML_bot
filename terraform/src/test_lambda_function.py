import logging
import os
from enum import Enum
from typing import Any

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
    ACK_WITH_SOURCE = 5

Response = dict[str, Any]

def verify_signature(event: dict[str, Any]) -> tuple[bool, Exception | None]:
    raw_body = event.get("rawBody")
    signature = event["params"]["header"].get("x-signature-ed25519")
    timestamp = event["params"]["header"].get("x-signature-timestamp")

    message = timestamp.encode() + raw_body.encode()
    verify_key = nacl.signing.VerifyKey(bytes.fromhex(PUBLIC_KEY))
    try:
        verify_key.verify(message, bytes.fromhex(signature))
    except Exception as e:
        return False, e

    return True, None

def handle_ping() -> Response:
    return {
        "type": ResponseTypes.PING_RESPONSE.value
    } 

def lambda_handler(event, context) -> Response:
    logger.warning(event)
    logger.warning(context)
    return {
        "type": ResponseTypes.PING_RESPONSE.value,
        "data": "Hello"
    }
    verified, verify_exception = verify_signature(event)
    if not verified and verify_exception is not None:
        raise Exception(f"Auth Exception {verify_exception}")

    body = event.get('body-json')
    if body.get("type") == 1:
        response: Response = handle_ping() 
    else:
        response = {
            "type": ResponseTypes.MESSAGE_NO_SOURCE.value,
            "data": {
                "tts": False,
                "content": "TEST RESP",
                "embeds": [],
                "allowed_mentions": []
            }
        }

    return response
