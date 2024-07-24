import configparser
import discord

config = configparser.ConfigParser()
config_dir = f'config.ini'

config.read(config_dir)

def save_config():
	with open(config_dir, 'w') as f:
		config.write(f)
	config.read(config_dir)

def reload_config():
	config.read(config_dir)

async def get_categories(ctx: discord.AutocompleteContext):
	#print('getting items')
	reload_config()
	return [item for item in config["STOCK"]["categories"].split(", ") if item.lower().startswith(ctx.value.lower())]