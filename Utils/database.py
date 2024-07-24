import os
import aiomysql
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

load_dotenv('.env')

class Database():
	def __init__(self, host, user, password, db):
		self.host = host
		self.user = user
		self.password = password
		self.db = db
		self.connection = None

	async def connect(self):
		self.connection = await aiomysql.create_pool(
			host = self.host,
			user = self.user,
			password = self.password,
			db = self.db,
			autocommit=True, maxsize = 100, pool_recycle=3600
		)

		if self.connection:
			return self.connection
		else:
			return False

	async def get_connection(self):
		if not self.connection:
			return await self.connect()
		else:
			return self.connection

	async def execute(self, query, params=None):
		if not self.connection:
			self.connection = await self.get_connection()

		async with self.connection.acquire() as con:
			async with con.cursor() as cursor:
				await cursor.execute(query, params)
				return cursor
			
db = Database(os.getenv(f"BILLGANGBOT_DB_HOST"),
			  os.getenv(f"BILLGANGBOT_DB_USERNAME"),
			  os.getenv(f"BILLGANGBOT_DB_PASSWORD"),
			  os.getenv(f"BILLGANGBOT_DB_NAME"))