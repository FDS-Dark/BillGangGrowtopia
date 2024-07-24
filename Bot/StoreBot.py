from asyncio import AbstractEventLoop
from discord import Guild, Status, Game, Message
from discord.ext.commands.errors import CommandNotFound, MissingRequiredArgument
from discord.ext.commands import Bot, Context
# from templates.visuals.views import Views
from dotenv import load_dotenv

import os

load_dotenv('.env')

class StoreBot(Bot):
    def __init__(self, *args, **kwargs):
        self.BOT_TOKEN = os.getenv(f"BILLGANGBOT_BOT_TOKEN")
        print(self.BOT_TOKEN)
        super().__init__(*args, **kwargs)

    async def startBot(self) -> None:
        if not self.BOT_TOKEN or self.BOT_TOKEN == "":
            print('Token not found!')
            exit()

        await super().start(self.BOT_TOKEN)

    async def on_ready(self):
        print("Bot is online!")
        # self.add_view(view=Views.LiveStockView(self))
        await self.change_presence(status=Status.online, activity=Game(name=f"Placeholder"))