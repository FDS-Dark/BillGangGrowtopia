import asyncio
from dotenv import load_dotenv
from Utils.config import config

from Utils.fast_api import app
from Utils.shared import storeBot

import os

async def run():
	try:
		await storeBot.startBot()
	except KeyboardInterrupt:
		await storeBot.logout()

asyncio.create_task(run())