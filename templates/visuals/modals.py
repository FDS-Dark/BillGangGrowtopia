import discord
from Utils.config import config
from Utils.utils import Utils
from templates.visuals.embeds import Embeds

import math
import re

class Modals():
	
	class AddAccount(discord.ui.Modal):
		def __init__(self, bot, db, *args, **kwargs) -> None:
			super().__init__(*args, **kwargs)
			self.bot = bot
			self.utils = Utils(bot)
			self.disabled = False
			self.add_item(discord.ui.InputText(label='Type ("UBICONNECT" or "LEGACY")'))
			self.add_item(discord.ui.InputText(label="GrowID (LEGACY) / Email (UBICONNECT)"))
			self.add_item(discord.ui.InputText(label="Password"))
			self.add_item(discord.ui.InputText(label="OTP Secret (UBICONNECT ONLY)", required = False))
			
		async def callback(self, interaction: discord.Interaction):
			await interaction.response.defer()
			account_type = self.children[0].value
			username = self.children[1].value
			password = self.children[2].value
			secret = None
			
			if account_type.lower() != "ubiconnect" and account_type.lower() != "legacy":
				await interaction.followup.send(content=f"The account type must either be 'LEGACY' or 'UBICONNECT'!", ephemeral=True)
				return

			if account_type.lower() == "ubiconnect":
				email_regex = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b'

				if not (re.fullmatch(email_regex, username)):
					await interaction.followup.send(content=f"That is not a valid email address! Please make sure your UbiConnect email is formatted correctly.", ephemeral=True)
					return
				
				if self.children[3].value != "":
					secret = self.children[3].value
				else:
					await interaction.followup.send(content=f"You must provide a OTP Secret for UbiConnect accounts!", ephemeral=True)
					return

			account_result, error_reason = await self.utils.addaccount(account_type, username, password, secret)

			if account_result:
				original_message = await interaction.original_response()
				await original_message.edit(embed = await self.utils.get_account_embed())
				await interaction.followup.send(content=f"Successfully added account! You can view all your accounts with `/manage accounts`", ephemeral=True)
				return
			else:
				if error_reason == "ALREADY_EXISTS":
					await interaction.followup.send(content=f"An account with that username already exists!", ephemeral=True)
					return
				else:
					await interaction.followup.send(content=f"Failed to add account! Please check <#{config["CHANNELS"]["logs"]}>!", ephemeral=True)
					return
			
	class RemoveAccount(discord.ui.Modal):
		def __init__(self, bot, db, *args, **kwargs) -> None:
			super().__init__(*args, **kwargs)
			self.bot = bot
			self.utils = Utils(bot)
			self.add_item(discord.ui.InputText(label='GrowID (LEGACY) / Email (UBICONNECT)', value=""))

		async def callback(self, interaction: discord.Interaction):
			await interaction.response.defer()
			account_name = self.children[0].value

			account_result = await self.utils.removeaccount(account_name)

			if not account_result:
				await interaction.followup.send(content=f"No account with that username exists! Please check `/manage accounts` for a list of current bots.", ephemeral=True)
				return
			else:
				original_message = await interaction.original_response()
				await original_message.edit(embed = await self.utils.get_account_embed())
			return
			
	class AddWorld(discord.ui.Modal):
		def __init__(self, bot, db, *args, **kwargs) -> None:
			super().__init__(*args, **kwargs)
			self.bot = bot
			self.utils = Utils(bot)
			self.disabled = False
			self.add_item(discord.ui.InputText(label='World Name'))
			self.add_item(discord.ui.InputText(label="Door ID"))
			self.add_item(discord.ui.InputText(label="Amount of DLs in world (leave blank for 0)", required=False, value=""))
			self.add_item(discord.ui.InputText(label="Background name for Blue Gem Locks"))
			self.add_item(discord.ui.InputText(label="Background name for Diamond Locks"))
			
		async def callback(self, interaction: discord.Interaction):
			await interaction.response.defer()
			world_name = self.children[0].value
			door_id = self.children[1].value
			start_amount = self.children[2].value
			bgl_bg_name = self.children[3].value
			dl_bg_name = self.children[4].value

			amounts = {
				"1796": 0,
				"7188": 0
			}

			positions = {}
			
			if not world_name.isalnum():
				await interaction.followup.send(content=f"The world name must only contain A-Z, 0-9 and no other characters!", ephemeral=True)
				return
			
			if not door_id.isalnum():
				await interaction.followup.send(content=f"The door ID must only contain A-Z, 0-9 and no other characters!", ephemeral=True)
				return
			
			if start_amount == "":
				start_amount = 0
			
			if type(start_amount) == str and start_amount.isnumeric():
				await interaction.followup.send(content=f"The amount of DLs must be numeric!", ephemeral=True)
				return
			else:
				start_amount = int(start_amount)
			
			if start_amount != 0:
				amounts["1796"] = start_amount % 100
				amounts["7188"] = math.floor(start_amount / 100)

			bgl_bg_item = await self.utils.find_item_id(bgl_bg_name)
			dl_bg_item = await self.utils.find_item_id(dl_bg_name)

			if not bgl_bg_item:
				await interaction.followup.send(content=f"Background Name for Blue Gem Locks must be an exact Growtopia item name!", ephemeral=True)
				return
			else:
				positions["7188"] = bgl_bg_item
			
			if not dl_bg_item:
				await interaction.followup.send(content=f"Background Name for Diamond Locks must be an exact Growtopia item name!", ephemeral=True)
				return
			else:
				positions["1796"] = dl_bg_item
			
			world_result, error_reason = await self.utils.addworld(world_name, door_id, amounts, positions)

			if world_result:
				original_message = await interaction.original_response()
				await original_message.edit(embed = await self.utils.get_world_embed())
				await interaction.followup.send(content=f"Successfully added world! You can view all your accounts with `/manage worlds`", ephemeral=True)
				return
			else:
				if error_reason == "ALREADY_EXISTS":
					await interaction.followup.send(content=f"A world with that name already exists!", ephemeral=True)
					return
				else:
					await interaction.followup.send(content=f"Failed to add world! Please check <#{config["CHANNELS"]["logs"]}>!", ephemeral=True)
					return
			
	class RemoveWorld(discord.ui.Modal):
		def __init__(self, bot, db, *args, **kwargs) -> None:
			super().__init__(*args, **kwargs)
			self.bot = bot
			self.utils = Utils(bot)
			self.add_item(discord.ui.InputText(label='World Name', value=""))

		async def callback(self, interaction: discord.Interaction):
			await interaction.response.defer()
			world_name = self.children[0].value

			world_result = await self.utils.removeworld(world_name)

			if not world_result:
				await interaction.followup.send(content=f"No world with that name exists! Please check `/manage worlds` for a list of current worlds.", ephemeral=True)
				return
			
			original_message = await interaction.original_response()
			await original_message.edit(embed = await self.utils.get_world_embed())
			await interaction.followup.send(content=f"Successfully removed `{world_name}` from your save world list!", ephemeral=True)
			return