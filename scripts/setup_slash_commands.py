import os

import requests

APP_ID = os.environ.get("DISCORD_BOT_APP_ID")
SERVER_ID = os.environ.get("DISCORD_BOT_SERVER_ID")
BOT_TOKEN = os.environ.get("DISCORD_BOT_TOKEN")

url = f"https://discord.com/api/v10/applications/{APP_ID}/guilds/{SERVER_ID}/commands"
print(url)

json = [
    {"name": "test_resp", "description": "Test command.", "options": []},
    {"name": "slow_test", "description": "Test slow editing command.", "options": []},
]

response = requests.put(url, headers={"Authorization": f"Bot {BOT_TOKEN}"}, json=json)

print(response.json())
