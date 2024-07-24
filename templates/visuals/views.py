import discord
from templates.visuals.modals import Modals
from Utils.config import config

from Utils.utils import Utils

class Views():

	class AccountManager(discord.ui.View):
		def __init__(self, bot, db, *args, **kwargs):
			super().__init__(*args, **kwargs, timeout=None) # timeout of the view must be set to None
			self.bot = bot
			self.db = db
			self.utils = Utils(self.bot)

		@discord.ui.button(label="Add Account", custom_id="add_account", style=discord.ButtonStyle.success) # the button has a custom_id set
		async def add_callback(self, button, interaction):
			await interaction.response.send_modal(Modals.AddAccount(title = "Add Account", bot = self.bot, db = self.db))

		@discord.ui.button(label="Remove Account", custom_id="remove_account", style=discord.ButtonStyle.danger) # the button has a custom_id set
		async def remove_callback(self, button, interaction):
			await interaction.response.send_modal(Modals.RemoveAccount(title = "Remove Account", bot = self.bot, db = self.db))
			
	class WorldManager(discord.ui.View):
		def __init__(self, bot, db, *args, **kwargs):
			super().__init__(*args, **kwargs, timeout=None) # timeout of the view must be set to None
			self.bot = bot
			self.db = db
			self.utils = Utils(self.bot)

		@discord.ui.button(label="Add World", custom_id="add_world", style=discord.ButtonStyle.success) # the button has a custom_id set
		async def add_callback(self, button, interaction):
			await interaction.response.send_modal(Modals.AddWorld(title = "Add World", bot = self.bot, db = self.db))

		@discord.ui.button(label="Remove World", custom_id="remove_world", style=discord.ButtonStyle.danger) # the button has a custom_id set
		async def remove_callback(self, button, interaction):
			await interaction.response.send_modal(Modals.RemoveWorld(title = "Remove World", bot = self.bot, db = self.db))