from Utils.shared import storeBot
from Utils.utils import Utils
from Utils.database import db
from fastapi import FastAPI, Request
from Utils.config import config, save_config
from pydantic import BaseModel
import discord
import os
import json

app = FastAPI()
utils = Utils(storeBot)

@app.post("/webhook")
async def webhook(request: Request):
	try:
		webhook_data = await request.json()
		# print(webhook_data)
		log_data = {}

		EVENT_TYPE = webhook_data['eventType']
		DATA = webhook_data['data']

		if 'ORDER' in EVENT_TYPE:
			if EVENT_TYPE == "ORDER_CREATED":
				quantity = 0
				for order in DATA['partOrders']:
					if order['productWithVariant']['id'] == int(os.getenv("BILLGANGBOT_1796")):
						quantity += order['quantity']
					elif order['productWithVariant']['id'] == int(os.getenv("BILLGANGBOT_7188")):
						quantity += order['quantity'] * 100
					else:
						await utils.send_log("ERROR", f"Order ID {DATA['id']} has an incorrect product id {order['productWithVariant']['id']}. Please fix!")
				
				if quantity != 0:
					await db.execute("INSERT INTO orders (shopId, orderId, quantity, orderInfo, status) VALUES (%s, %s, %s, %s, %s)", [DATA['shopId'], DATA['id'], quantity, json.dumps(order), 'created'])
					print("Final order quantity: ", quantity)
			elif EVENT_TYPE == "ORDER_COMPLETED":
				await db.execute("UPDATE orders SET status = %s WHERE orderId = %s", ['paid', DATA['id']])
		elif 'CHARGE' in EVENT_TYPE:
			pass
		await utils.send_log(webhook_data['eventType'], webhook_data['eventType'])
	except Exception as e:
		await utils.send_log('ERROR', e)

class UpdateAmount(BaseModel):
	world: str
	amounts: dict

@app.post("/update_amount")
async def update_amount(data: UpdateAmount):
	try:
		print(data.amounts)
		await db.execute("UPDATE save_worlds SET amounts = %s WHERE world = %s", [json.dumps(data.amounts), data.world])
		return "Success", 200
	except Exception as e:
		await utils.send_log("ERROR", f"Error while updating save world amount:\n\n{e}")
		return "Error", 404
	
@app.post("/distribute")
async def distribute_errors(request: Request):
	try:
		content = await request.json()
		await utils.send_log("ERROR", f"An unexpected distribute error occurred:\n\n{content['error_code']}\n{content['error']}")
	except Exception as e:
		await utils.send_log("ERROR", f"An unexcepted error occurred while trying to log distribute error:\n\n{e}")

@app.get("/test")
async def test(request: Request):
	print(os.getenv("BILLGANGBOT_7188"))
	print(os.getenv("BILLGANGBOT_1796"))