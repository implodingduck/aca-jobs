import os

from azure.identity import DefaultAzureCredential
from azure.storage.queue import QueueClient


ACCOUNT_URL = os.environ["ACCOUNT_URL"]
QUEUE_NAME = os.environ["QUEUE_NAME"]

print(f"Account URL: {ACCOUNT_URL}")
print(f"Queue name: {QUEUE_NAME}")

credential = DefaultAzureCredential()
if credential:
    print(f"I got a credential! {credential}")

client = QueueClient(account_url=ACCOUNT_URL, queue_name=QUEUE_NAME, credential=credential)

if client:
    print(f"I got a client! {client}")

messages = client.receive_messages(max_messages=5)
for msg in messages:
    print(f"Message: {msg.content}")
    client.delete_message(msg)

print("Done!")