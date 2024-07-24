import discord

from discord.ext import commands, tasks, pages
from discord.commands import SlashCommandGroup
from discord.errors import CheckFailure
from Utils.config import config
from templates.visuals.embeds import Embeds

from Utils.utils import Utils
from Utils.database import db
from templates.visuals.views import Views
from Utils.config import config, save_config

import os
import math
import time
import json
import aiohttp
from datetime import datetime

class Admin(commands.Cog):
	def __init__(self, bot):
		self.bot = bot
		self.name = "Admin"
		self.db = db
		self.utils = Utils(self.bot)

	admin = SlashCommandGroup("admin", "Admin commands")
	manage = SlashCommandGroup("manage", "Management commands")
	
	async def cog_check(self, ctx):
		# Implement your cog check logic here
		return ctx.user.id == 778842686031003721

	# @commands.Cog.listener()
	# async def on_application_command_error(self, ctx, error):
	# 	if isinstance(error, CheckFailure) and ctx.cog.name == "Admin":
	# 		await ctx.respond("You do not have permission to run this command!", ephemeral=True)
	# 	else:
	# 		print(error)

	@tasks.loop(seconds=15)
	async def handle_orders(self):
		cursor = await self.db.execute("SELECT * FROM orders WHERE status = %s", ["paid"])
		results = await cursor.fetchall()

		account_cursor = await self.db.execute("SELECT * FROM save_accounts WHERE status = %s ORDER BY RAND() LIMIT 1", ["active"])
		account_details = await account_cursor.fetchone()

		if len(account_details) < 1:
			await self.utils.send_log("ERROR", f"No valid save accounts found! <@{config['BOT']['owner_id']}>")

		if len(results) >= 0:
			for result in results:

				world_cursor = await self.db.execute("SELECT * FROM save_worlds")
				world_results = await world_cursor.fetchall()

				if len(world_results) < 1:
					await self.utils.send_log("ERROR", f"Failed to fulfill order ID {results[1]} due to lack of save worlds. Please add save worlds with /addsave.")
					await self.db.execute("UPDATE orders SET status = %s WHERE orderId = %s", ["error", results[1]])
					return

				world_data = await self.utils.get_world_combination(result[2], world_results)

				if len(world_data) == 0:
					await self.utils.send_log("ERROR", f"Failed to fulfill order ID {results[1]} due to lack of inventory. Consider running `/manage sync` if you believe this is an error.")
					await self.db.execute("UPDATE orders SET status = %s WHERE orderId = %s", ["error", results[1]])
					return

				async with aiohttp.ClientSession() as session:
					async with session.get(f"https://pg-api.billgang.com/v1/dash/shops/{os.getenv("BILLGANGBOT_STORE_ID")}/orders/{results[1]}", headers = {"Authorization": f"Bearer {os.getenv("BILLGANGBOT_API_KEY")}"}) as response:
						if response.status == 200:
							order_info = await response.json()

							output_world = order_info['data']['metadata']['World Name']
				
				if not output_world:
					await self.utils.send_log("ERROR", f"Failed to fulfill order ID {results[1]} as no world name was. Please fix!")
					await self.db.execute("UPDATE orders SET status = %s WHERE orderId = %s", ["error", results[1]])
					return
				
				data = {
					"authorization": os.getenv("BILLGANGBOT_LUCIFER_AUTH"),
					"account_details": await self.utils.convert_account_data(account_details),
					"world_data": world_data,
					"quantity": result[2],
					"output_world": output_world.upper()
				}

				async with aiohttp.ClientSession() as session:
					async with session.post(f"http://{os.getenv('BILLGANGBOT_LUCIFER_IP')}:{os.getenv('BILLGANGBOT_LUCIFER_PORT')}/delivery", json=data) as response:
						if response.status == 200:
							content = await response.json()
							await self.utils.send_log('DELIVERY', f"{content['content']}\n\nTime: <t:{content['time']}>")
							return
						else:
							content = await response.json()
							await self.db.execute("UPDATE orders SET status = %s WHERE orderId = %s", ["error", results[1]])
							await self.utils.send_log('ERROR', f"Error code {response.status} while delivering order {result[1]}\n\n{content['error_code']}\n{content['error']}")
							return

		else:
			print("There are no orders to handle.")

	@admin.command(name = "distribute", description = "Auto Distribute stock")
	async def distribute(self, ctx):
		await ctx.defer(ephemeral=True)
		cursor = await self.db.execute("SELECT * FROM save_accounts ORDER BY RAND() LIMIT 1")
		account_details = await cursor.fetchone()

		if len(account_details) < 1:
			message = await ctx.respond(embed = discord.Embed(title = "An error occurred", description="There are no save accounts found in the database. Please add a save account with /addaccount", color = discord.Color.red()), ephemeral=True)
			return
		
		data = {
			"authorization": os.getenv("BILLGANGBOT_LUCIFER_AUTH"),
			"account_details": account_details
		}

		message = await ctx.respond(embed = discord.Embed(title = "Please Wait", description="A bot is currently finding a random world to join. Please wait.", color = discord.Color.green()), ephemeral=True)

		async with aiohttp.ClientSession() as session:
			async with session.post(f"http://{os.getenv('BILLGANGBOT_LUCIFER_IP')}:{os.getenv('BILLGANGBOT_LUCIFER_PORT')}/distribute1", json=data) as response:
				if response.status == 200:
					content = await response.json()
					await message.edit(embed = discord.Embed(title = "World Found", description = f"Please join the world **{content['world_name']}** and drop all BGLs/DLs to the bot account **{content['bot_name']}**.", color = discord.Color.green()))
					data = {
						"authorization": os.getenv("BILLGANGBOT_LUCIFER_AUTH"),
						"bot_name": content['bot_name']
					}
					async with aiohttp.ClientSession() as session:
						async with session.post(f"http://{os.getenv('BILLGANGBOT_LUCIFER_IP')}:{os.getenv('BILLGANGBOT_LUCIFER_PORT')}/distribute2", json=data) as response:
							if response.status == 200:
								content = await response.json()
								await message.edit(embed = discord.Embed(title = "Please Wait", description="Updating BillGang product stock..."))
								
								world_cursor = await self.db.execute("SELECT * FROM save_worlds")
								world_data = await world_cursor.fetchall()

								total = {
									"1796": 0,
									"7188": 0
								}

								for world in world_data:
									amounts = json.loads(world[2])

									for key in amounts.keys():
										total[key] += amounts[key]

								for key in total.keys():
									await self.utils.update_billgang_stock(key, total[key], 'set')
									
								await message.edit(embed = discord.Embed(title = "Success", description=content['content']))

							elif response.status == 404:
								await self.utils.send_log("ERROR", f"Error {response.status}\n\n{content['error_code']}\n{content['error']}")
								return
							else:
								await self.utils.send_log("ERROR", f"Error {response.status}\n\n{content['error']}")
								return
				elif response.status == 404:
					content = await response.json()
					await message.edit(embed = discord.Embed(title = "Error", description = f"An error occured while attempting to find a random world.\n\nError Code: {content['error_code']}\nError Message: {content['error']}", color = discord.Color.green()))
					await self.utils.send_log("ERROR", f"{content['error_code']}\n\n{content['error']}")
					return
				else:
					content = await response.text()
					await message.edit(embed = discord.Embed(title = "Error", description = f"An error occured while attempting to find a random world.\n\nError Message: {content['error']}"), color = discord.Color.green())
					return

	@admin.command(name = "send", description = "Send stock to a world!")
	async def send(self, ctx, world_name: discord.Option(str, description="World Name", default = ""), amount: discord.Option(int, description="Amount of DLs to deliver (must be less than total stock)")):
		await ctx.defer(ephemeral=True)

		if world_name == "":
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description="You must give a world name to send stock to!", color = discord.Color.red()))
			return

		if not world_name.isalnum():
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description="World names can only contain the characters A-Z, 0-9!", color = discord.Color.red()))
			return
		
		if len(world_name) > 24:
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description="World names can only be 24 characters long!", color = discord.Color.red()))
			return
		
		world_cursor = await self.db.execute("SELECT * FROM save_worlds")
		world_results = await world_cursor.fetchall()

		if len(world_results) < 1:
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description="You don't have any save worlds! Please add worlds with `/manage worlds` and try again.", color = discord.Color.red()))
			return
		
		account_cursor = await self.db.execute("SELECT * FROM save_accounts ORDER BY RAND() LIMIT 1")
		account_details = await account_cursor.fetchone()

		if len(account_details) < 1:
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description="You don't have any save accounts! Please add accounts with `/manage accounts` and try again.", color = discord.Color.red()))
			return

		world_data = await self.utils.get_world_combination(amount, world_results)

		if len(world_data) == 0:
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description="No combination of worlds is able to fulfill this amount of stock! If you believe this is a mistake, use `/manage sync` to sync world stock counts to the database.", color = discord.Color.red()))
			return
		
		data = {
			"authorization": os.getenv("BILLGANGBOT_LUCIFER_AUTH"),
			"account_details": await self.utils.convert_account_data(account_details),
			"world_data": await self.utils.get_world_combination(world_data),
			"quantity": amount,
			"output_world": world_name.upper()
		}

		async with aiohttp.ClientSession() as session:
			async with session.post(f"http://{os.getenv('BILLGANGBOT_LUCIFER_IP')}:{os.getenv('BILLGANGBOT_LUCIFER_PORT')}/delivery", json=data) as response:
				if response.status == 200:
					content = await response.json()
					await self.utils.send_log('DELIVERY', f"{content['content']}\n\nTime: <t:{content['time']}> **[MANUAL]**")
					await ctx.respond(embed = discord.Embed(title = "Success", description=content['content'], color = discord.Color.green()))
					return
				else:
					content = await response.json()
					await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description=f"An error occured while delivering! Please check <#{config["CHANNELS"]["logs"]}>.", color = discord.Color.red()))
					await self.utils.send_log('ERROR', f"Error code {response.status} while manually delivering stock.\n\n{content['error_code']}\n{content['error']}")
					return

	@manage.command(name = "accounts", description = "Manage save accounts")
	async def accounts(self, ctx):
		await ctx.defer(ephemeral=True)

		legacy_account_cursor = await self.db.execute("SELECT * FROM save_accounts WHERE type = %s", ["LEGACY"])
		legacy_accounts = await legacy_account_cursor.fetchall()
		legacy_string = ""
		
		for account in legacy_accounts:
			legacy_string += f"- {account[1]}:||{account[2]}||"

		ubiconnect_account_cursor = await self.db.execute("SELECT * FROM save_accounts WHERE type = %s", ["UBICONNECT"])
		ubiconnect_accounts = await legacy_account_cursor.fetchall()
		ubiconnect_string = ""

		for account in ubiconnect_accounts:
			ubiconnect_string += f"- {account[1]}:||{account[2]}||:||{account[3]}||\n"
		
		await ctx.respond(embed = await self.utils.get_account_embed(), view = Views.AccountManager(self.bot, self.db), ephemeral=True)

	@manage.command(name = "worlds", description = "Manage save worlds")
	async def worlds(self, ctx):
		await ctx.defer(ephemeral=True)

		world_cursor = await self.db.execute("SELECT * FROM save_worlds")
		worlds = await world_cursor.fetchall()
		world_string = ""
		
		for world in worlds:
			world_string += f"- {world[0]}:||{world[1]}|| - {world[2]} {config['EMOJIS']['diamond_lock']}\n"

		await ctx.respond(embed = await self.utils.get_world_embed(), view = Views.WorldManager(self.bot, self.db), ephemeral=True)

	@manage.command(name = "view_world", description = "View save world information")
	async def view_world(self, ctx, world_name: discord.Option(str, description="World Name")):
		await ctx.defer(ephemeral=True)
		world_cursor = await self.db.execute("SELECT * FROM save_worlds WHERE world = %s", [world_name])
		world = await world_cursor.fetchone()

		if len(world) > 0:
			dropped_string = ""
			positions_string = ""

			amounts = json.loads(world[2])
			positions = json.loads(world[3])

			# dropped_string += (f"{amounts['7188']} Blue Gem Locks" if amounts['7188'] > 0 else "") + (f" and " if amounts['7188'] > 0 and amounts['1796'] > 0 else "") + (f"{amounts['1796']} Diamond Locks" if amounts['1796'] > 0 else "")
			dropped_string += (f"{config["EMOJIS"]["blue_gem_lock"]} {amounts['7188']}" if amounts['7188'] > 0 else "") + (f" and " if amounts['7188'] > 0 and amounts['1796'] > 0 else "") + (f"{config["EMOJIS"]["diamond_lock"]} {amounts['1796']}" if amounts['1796'] > 0 else "")
			
			for key in positions.keys():
				if key == "1796":
					emoji = config["EMOJIS"]['diamond_lock']
				elif key == "7188":
					emoji = config["EMOJIS"]['blue_gem_lock']
					
				positions_string += f"- {emoji} - {await self.utils.find_item_name(positions[key])}\n"
			
			await ctx.respond(embed = discord.Embed(title = "World Information", description = f"__**World Name**__\n- {world_name}\n\n__**Door ID**__\n- ||{world[1]}||\n\n__**Dropped Items**__\n- {dropped_string}\n\n__**Item Positions**__\n{positions_string}", color = discord.Color.blurple()))
		else:
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description = f"No world exists with the name `{world_name}`! Please enter a world name found in `/manage worlds`.", color = discord.Color.red()))
	

	@manage.command(name = "sync", description = "Sync save world counts to database")
	async def sync(self, ctx):
		await ctx.defer(ephemeral=True)

		world_cursor = await self.db.execute("SELECT * FROM save_worlds")
		world_data = await world_cursor.fetchall()

		account_cursor = await self.db.execute("SELECT * FROM save_accounts ORDER BY RAND() LIMIT 1")
		account_details = await account_cursor.fetchone()

		if len(world_data) == 0:
			await ctx.respond(embed = discord.Embed(title = "Unsuccessful Command", description = "There are currently no save worlds in the database! Please add some with `/manage worlds`", color = discord.Color.red()))
			return
		
		post_data = {
			'authorization': os.getenv("BILLGANGBOT_LUCIFER_AUTH"),
			'account_details': await self.utils.convert_account_data(account_details),
			'world_data': await self.utils.convert_world_data(world_data)
		}
		
		message = await ctx.respond(embed = discord.Embed(title = "Please Wait", description="Currently syncing save worlds counts to database...", color = discord.Color.orange()))
		async with aiohttp.ClientSession() as session:
			async with session.post(f"http://{os.getenv('BILLGANGBOT_LUCIFER_IP')}:{os.getenv('BILLGANGBOT_LUCIFER_PORT')}/sync", json=post_data) as response:
				if response.status == 200:
					await message.edit(embed = discord.Embed(title = "Success", description="Successfully synced save world counts to database! Updating BillGang stock counts...", color = discord.Color.green()))

					world_cursor = await self.db.execute("SELECT * FROM save_worlds")
					world_data = await world_cursor.fetchall()

					total = {
						"1796": 0,
						"7188": 0
					}

					for world in world_data:
						amounts = json.loads(world[2])

						for key in amounts.keys():
							total[key] += amounts[key]

					for key in total.keys():
						await self.utils.update_billgang_stock(key, total[key], 'set')

				else:
					print(await response.text())
					content = await response.json()
					await self.utils.send_log("ERROR", f"There was an error syncing world counts to database!\n\n{content['error_code']}\n{content['error']}")

	@manage.command(name = "sync_billgang", description = "Sync current database counts to BillGang stock count")
	async def sync_billgang(self, ctx):
		await ctx.defer(ephemeral=True)

		message = await ctx.respond(embed = discord.Embed(title = "Please wait", description = "Updating all stock counts on BillGang. Please wait...", color = discord.Color.orange()))

		world_cursor = await self.db.execute("SELECT * FROM save_worlds")
		world_data = await world_cursor.fetchall()

		total = {
			"1796": 0,
			"7188": 0
		}

		for world in world_data:
			amounts = json.loads(world[2])

			for key in amounts.keys():
				total[key] += amounts[key]
		
		for key in total.keys():
			await self.utils.update_billgang_stock(key, total[key], 'set')

		await message.edit(embed = discord.Embed(title = "Success", description = "Successfully updated all stock counts on BillGang", color = discord.Color.green()))

def setup(bot):
	bot.add_cog(Admin(bot))