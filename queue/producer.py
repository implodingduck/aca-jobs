import os
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from dotenv import load_dotenv

load_dotenv() 

conn_str = os.environ['SB_CONN_STR']
queue_name = "deathstarstatus"

print(f"Connection string: {conn_str}")

app_props = {
    "producer": "producer.py",
    "env": "dev",
    "repo": "aca-dapr"
}

with ServiceBusClient.from_connection_string(conn_str) as client:
    with client.get_queue_sender(queue_name) as sender:
        # Sending a single message
        single_message = ServiceBusMessage("Single message", application_properties=app_props)
        sender.send_messages(single_message)

        # Sending a list of messages
        messages = [ServiceBusMessage("First message", application_properties=app_props), ServiceBusMessage("Second message", application_properties=app_props)]
        sender.send_messages(messages)

        single_message = ServiceBusMessage("triggerdelay", application_properties=app_props)
        sender.send_messages(single_message)
print("Done!")