import discord

class Embeds():

	class Order(discord.Embed):
		def __init__(self, *args, **kwargs):
			super().__init__(title = "Order Log", color = discord.Color.green(), *args, **kwargs)

	class Delivery(discord.Embed):
		def __init__(self, *args, **kwargs):
			super().__init__(title = "Delivery Log", color = discord.Color.nitro_pink(), *args, **kwargs)

	class Charge(discord.Embed):
		def __init__(self, *args, **kwargs):
			super().__init__(title = "Charge Log", color = discord.Color.orange(), *args, **kwargs)

	class Review(discord.Embed):
		def __init__(self, *args, **kwargs):
			super().__init__(title = "Review Log", color = discord.Color.blue(), *args, **kwargs)

	class Warehouse(discord.Embed):
		def __init__(self, *args, **kwargs):
			super().__init__(title = "Warehouse Log", color = discord.Color.purple(), *args, **kwargs)

	class Ticket(discord.Embed):
		def __init__(self, *args, **kwargs):
			super().__init__(title = "Ticket Log", color = discord.Color.yellow(), *args, **kwargs)

	class Error(discord.Embed):
		def __init__(self, *args, **kwargs):
			super().__init__(title = "Unexpected Error", color = discord.Color.red(), *args, **kwargs)