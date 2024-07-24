from random import choices
import string
from discord.bot import Bot
from discord import Intents
from Bot.StoreBot import StoreBot
from os import listdir
from Utils.config import config


class StoreInitializer:
	def __init__(self) -> None:
		self.__intents = Intents.all()
		self.__bot = self.__create_bot()
		self.__add_cogs(self.__bot)

	def getBot(self) -> StoreBot:
		return self.__bot

	def __create_bot(self) -> StoreBot:
		bot = StoreBot(intents=self.__intents, debug_guilds=[int(config["BOT"]["server_id"])], command_prefix=".")
		return bot

	def __add_cogs(self, bot: Bot) -> None:
		cogsStatus = []
		for cog in config["BOT"]["cogs"].split(", "):
			print(f'loading cogs.{cog}')
			bot.load_extension(f"cogs.{cog}")