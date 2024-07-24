import discord
import os

from dotenv import load_dotenv

from Bot.StoreInitializer import StoreInitializer

initializer = StoreInitializer()
storeBot = initializer.getBot()