import os
from io import BytesIO
from logging import getLogger
from typing import Any

import numpy as np
import requests
from PIL import Image

logger = getLogger(__name__)
PUBLIC_KEY = os.environ.get("DISCORD_PUBLIC_KEY")
APP_ID = os.environ.get("DISCORD_APP_ID")
BOT_TOKEN = os.environ.get("DISCORD_BOT_TOKEN")


def lambda_handler(event, context) -> dict[str, Any]:
    logger.warning(event)
    logger.warning(context)
    
    interaction_token = event['interaction_token']

    patch_url = f"https://discord.com/api/v10/webhooks/{APP_ID}/{interaction_token}/messages/@original"

    json_payload = {
        "type":7,
        "content": "EDITED",
        "embeds": [
            {
                "title": "Test Embed",
                "description": "Describe Embed",
                "thumbnail": {
                    "url": "attachment://filename.jpg"
                },
                "image": {
                    "url": "attachment://filename.jpg"
                },
            }
        ],
        "attachments": [
            {
                "id": 0,
                "description": "test image",
                "filename": "filename.jpg"
            }
        ]
    }
    headers = {
        "Authorization": f"Bot {BOT_TOKEN}"
    }
    img_data = np.random.randint(0, 255, (100, 100, 3), np.uint8)
    img = Image.fromarray(img_data)
    img_file = BytesIO()
    img.save(img_file, format="jpeg")
    img_file.seek(0)
    files = {'files[0]': ("filename.jpg", img_file, "image/jpg")}


    try:
        r = requests.patch(patch_url, headers=headers, json=json_payload, files=files)
    except Exception as e:
        return {
            'statusCode': 501,
            'body': {
                'exception': str(e) 
            }
        }

    return {
        'statusCode': 200,
        'body': {'data': 'Success!'}
    }

    



     
    
