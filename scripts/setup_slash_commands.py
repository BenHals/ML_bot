import os

import requests

APP_ID = os.environ.get("DISCORD_BOT_APP_ID") 
SERVER_ID = os.environ.get("DISCORD_BOT_SERVER_ID")
BOT_TOKEN = os.environ.get("DISCORD_BOT_TOKEN")

print(APP_ID)
print(SERVER_ID)
print(BOT_TOKEN)

# global commands are cached and only update every hour
# url = f'https://discord.com/api/v10/applications/{APP_ID}/commands'

# while server commands update instantly
# they're much better for testing
url = f'https://discord.com/api/v10/applications/{APP_ID}/guilds/{SERVER_ID}/commands'
print(url)

json = [
  {
    'name': 'bleb',
    'description': 'Test command.',
    'options': []
  }
]

response = requests.put(url, headers={
  'Authorization': f'Bot {BOT_TOKEN}'
}, json=json)

print(response.json())
