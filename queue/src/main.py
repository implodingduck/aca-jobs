import os
from azure.servicebus import ServiceBusClient
from azure.identity import DefaultAzureCredential

FULLY_QUALIFIED_NAMESPACE = os.environ["SERVICEBUS_FULLY_QUALIFIED_NAMESPACE"]
QUEUE_NAME = os.environ["SERVICE_BUS_QUEUE_NAME"]

credential = DefaultAzureCredential()
if credential:
    print("I got a credential!")

servicebus_client = ServiceBusClient(FULLY_QUALIFIED_NAMESPACE, credential)

if servicebus_client:
    print("I got a client!")

with servicebus_client:
    receiver = servicebus_client.get_queue_receiver(queue_name=QUEUE_NAME)
    with receiver:
        received_msgs = receiver.receive_messages(max_message_count=10, max_wait_time=5)
        for msg in received_msgs:
            print(str(msg))
            receiver.complete_message(msg)

print("Done!")