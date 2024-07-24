from Utils.config import config, save_config
# from modules.shared import db
from Utils.database import db
from templates.visuals.embeds import Embeds

import aiomysql
import discord
import os
import shutil
import json
import math
import time
import zipfile
import re
import aiohttp

connection = None

class Utils():
	def __init__(self, bot):
		self.connection = None
		self.db = db
		self.bot = bot
		self.items = []
		self.lowered_items = []
		
	# Permissions
	async def check_admin(self, user_id):
		admin_users = config["PERMS"]["admin_users"].split(", ")
		admin_roles = config["PERMS"]["admin_roles"].split(", ")

		return str(user_id) in admin_users or user_id in admin_roles
	
	# Helpful
	async def load_items(self):
		with open('item_names.txt', 'r') as f:
			lines = f.readlines()
			for line in lines:
				#if "null" not in line:
				self.items.append(line.replace("\n", ""))
				self.lowered_items.append(line.replace("\n", "").lower())
	
	# Logging
	async def send_log(self, log_type, text):
		log_channel = self.bot.get_channel(int(config["CHANNELS"]["logs"]))
		
		if "ORDER_" in log_type:
			await log_channel.send(embed = Embeds.Order(description = text))
		elif "DELIVERY" in log_type:
			await log_channel.send(embed = Embeds.Delivery(description = text))
		elif "CHARGE_" in log_type:
			await log_channel.send(embed = Embeds.Charge(description = text))
		elif "REVIEW_" in log_type:
			await log_channel.send(embed = Embeds.Review(description = text))
		elif "WAREHOUSE_" in log_type:
			await log_channel.send(embed = Embeds.Warehouse(description = text))
		elif "TICKET_" in log_type:
			await log_channel.send(embed = Embeds.Ticket(description = text))
		elif "ERROR" in log_type:
			await log_channel.send(embed = Embeds.Error(description = text))
		else:
			print('no log type found')

	# Other
	async def get_world_combination(self, target_amount, worlds):
		for world in worlds:
			world = await self.convert_world_data(world)
			world['total_amount'] = world['amounts']["1796"] + (100 * world['amounts']["7188"])
			world['amount'] = 0  # Initialize the amount to be taken from each world
	
		sorted_worlds = sorted(worlds, key=lambda x: x['total_amount'], reverse=True)
	
		for world in sorted_worlds:
			if world['total_amount'] >= target_amount:
				world['amount'] = target_amount
				return [world]
	
		current_total = 0
		selected_worlds = []
	
		for world in sorted_worlds:
			if current_total >= target_amount:
				break
			amount_needed = target_amount - current_total
			amount_to_take = min(world['total_amount'], amount_needed)
			world['amount'] = amount_to_take
			current_total += amount_to_take
			selected_worlds.append(world)
	
		if current_total >= target_amount:
			return selected_worlds
	
		print("Error: Target amount cannot be achieved with the available worlds.")
		return []
	
	async def update_billgang_stock(self, item_id, new_stock, method):
		product_info = None
		env_id = f'BILLGANGBOT_{item_id}'
		headers = {
			'Authorization': f'Bearer {os.getenv("BILLGANGBOT_API_KEY")}'
		}

		async with aiohttp.ClientSession() as session:
			async with session.get(f"https://pg-api.billgang.com/v1/dash/shops/{os.getenv("BILLGANGBOT_STORE_ID")}/products/{os.getenv(env_id)}", headers=headers) as response:
				if response.status == 200:
					print("Got product info")
					response = await response.json()
					product_info = response['data']
					if method == 'set':
						product_info['variants'][0]['deliveryConfigurations'][0]['stock'] = new_stock
					elif method == 'add':
						product_info['variants'][0]['deliveryConfigurations'][0]['stock'] += new_stock

					updated_product_info = {
						"name": product_info['name'],
						"description": product_info['description'],
						"uniquePath": product_info['uniquePath'],
						"imageIds": [image['id'] for image in product_info['images']],
						"visibility": product_info['visibility'],
						'variants': product_info['variants'],
						'seo': product_info['seo']
					}
				else:
					await self.send_log("ERROR", f"Error getting info of product code {os.getenv(env_id)}:\n\n{await response.json()}")
					return
				
		if product_info and updated_product_info:
			async with aiohttp.ClientSession() as session:
				async with session.put(f"https://pg-api.billgang.com/v1/dash/shops/{os.getenv("BILLGANGBOT_STORE_ID")}/products/{os.getenv(env_id)}", headers = headers, json=updated_product_info) as response:
					if response.status != 200:
						try:
							content = await response.json()
						except Exception as e:
							content = await response.text()
							
						await self.send_log("ERROR", f"Error updating BillGang product stock!\n\n{content}")
						return False
					else:
						return response.status
		else:
			await self.send_log("ERROR", f"Error getting info of product code {os.getenv(env_id)}:\n\n{await response.json()}")
			return
					
	async def addaccount(self, account_type, username, password, secret = None):
		try:
			cursor = await self.db.execute("SELECT COUNT(*) FROM save_accounts WHERE username = %s AND type = %s", [username, account_type])
			count = await cursor.fetchone()

			if count[0] >= 1:
				return False, "ALREADY_EXISTS"
			
			if account_type.lower() == "ubiconnect":
				await self.db.execute("INSERT INTO save_accounts (type, username, password, secret) VALUES (%s, %s, %s, %s)", [account_type, username, password, secret])
				return True, None
			elif account_type.lower() == "legacy":
				await self.db.execute("INSERT INTO save_accounts (type, username, password) VALUES (%s, %s, %s)", [account_type, username, password])
				return True, None
		except Exception as e:
			await self.send_log("ERROR", f"Error while adding account to database:\n\n{e}")
			return False, "ERROR"
		
	async def removeaccount(self, username):
		try:
			cursor = await self.db.execute("SELECT COUNT(*) FROM save_accounts WHERE username = %s", [username])
			count = await cursor.fetchone()

			if count[0] >= 1:
				await self.db.execute("DELETE FROM save_accounts WHERE username = %s", [username])
				return True, None
			else:
				return False, None
		except Exception as e:
			await self.send_log("ERROR", f"Error while removing account from database:\n\n{e}")
			return False, None

	async def addworld(self, world_name, door_id, amounts, positions):
		try:
			cursor = await self.db.execute("SELECT COUNT(*) FROM save_worlds WHERE world = %s", [world_name])
			count = await cursor.fetchone()

			if count[0] >= 1:
				return False, "ALREADY_EXISTS"
			
			await self.db.execute("INSERT INTO save_worlds (world, door_id, amounts, positions) VALUES (%s, %s, %s, %s)", [world_name, door_id, json.dumps(amounts), json.dumps(positions)])
			return True, None
		except Exception as e:
			await self.send_log("ERROR", f"Error while adding world to database:\n\n{e}")
			return False, "ERROR"
		
	async def removeworld(self, world_name):
		try:
			cursor = await self.db.execute("SELECT COUNT(*) FROM save_worlds WHERE world = %s", [world_name])
			count = await cursor.fetchone()

			if count[0] >= 1:
				await self.db.execute("DELETE FROM save_worlds WHERE world = %s", [world_name])
				return True, None
			else:
				return False, None
		except Exception as e:
			await self.send_log("ERROR", f"Error while removing world from database:\n\n{e}")
			return False, None
		
	async def get_account_embed(self):
		legacy_account_cursor = await db.execute("SELECT * FROM save_accounts WHERE type = %s", ["LEGACY"])
		legacy_accounts = await legacy_account_cursor.fetchall()
		legacy_string = ""
		
		for account in legacy_accounts:
			legacy_string += f"- {account[1]}:||{account[2]}||"

		ubiconnect_account_cursor = await db.execute("SELECT * FROM save_accounts WHERE type = %s", ["UBICONNECT"])
		ubiconnect_accounts = await ubiconnect_account_cursor.fetchall()
		ubiconnect_string = ""

		for account in ubiconnect_accounts:
			ubiconnect_string += f"- {account[1]}:||{account[2]}||:||{account[3]}||\n"
		
		return discord.Embed(title = "Account Manager", description = f"__**Current Legacy Accounts**__\n{legacy_string if legacy_string != "" else '- None'}\n\n__**Current UbiConnect Accounts**__\n{ubiconnect_string if ubiconnect_string != "" else "- None"}", color = discord.Color.blurple())
	
	async def get_world_embed(self):
		world_cursor = await db.execute("SELECT * FROM save_worlds")
		worlds = await world_cursor.fetchall()
		world_string = ""
		
		for world in worlds:
			world_count = 0
			world_items = json.loads(world[2])
			for key in world_items.keys():
				if key == "1796": 
					world_count += world_items[key]
				elif key == "7188":
					world_count += world_items[key] * 100

			world_string += f"- {world[0]}:||{world[1]}|| - {world_count} {config['EMOJIS']['diamond_lock']}\n"

		return discord.Embed(title = "World Manager", description = f"__**Current Worlds**__\n{world_string if world_string != "" else '- None'}", color = discord.Color.blurple())

	async def find_item_id(self, item_name, lst = "normal"):
		if len(self.items) or len(self.lowered_items) == 0:
			await self.load_items()

		if lst.lower() == "normal":
			item_list = self.items
		elif lst.lower() == "lowered":
			item_list = self.lowered_items

		if item_name in item_list:
			return item_list.index(item_name)
		else:
			return False
		
	async def find_item_name(self, item_id):
		if len(self.items) or len(self.lowered_items) == 0:
			await self.load_items()
			
		if len(self.items) > item_id:
			return self.items[item_id]
		else:
			return False
		
	async def convert_world_data(self, world_data):
		world_data = [
		{
			'name': world[0], 
			'id': world[1], 
			'amounts': json.loads(world[2]), 
			'positions': json.loads(world[3])
		} 
		for world in world_data
		]
		return world_data
	
	async def convert_account_data(self, account_data):
		account_data = {
			'type': account_data[0],
			'username': account_data[1],
			'password': account_data[2],
			'secret': account_data[3],
			'status': account_data[4]
		}

		return account_data