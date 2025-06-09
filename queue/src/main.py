import os
from azure.servicebus import ServiceBusClient
from azure.identity import DefaultAzureCredential

import logging
import sys

# handler = logging.StreamHandler(stream=sys.stdout)
# log_fmt = logging.Formatter(fmt="%(asctime)s | %(threadName)s | %(levelname)s | %(name)s | %(message)s")
# handler.setFormatter(log_fmt)
# logger = logging.getLogger('azure.servicebus')
# logger.setLevel(logging.DEBUG)
# logger.addHandler(handler)


FULLY_QUALIFIED_NAMESPACE = os.environ["SERVICEBUS_FULLY_QUALIFIED_NAMESPACE"]
QUEUE_NAME = os.environ["SERVICE_BUS_QUEUE_NAME"]

print(f"Fully qualified namespace: {FULLY_QUALIFIED_NAMESPACE}")
print(f"Queue name: {QUEUE_NAME}")

credential = DefaultAzureCredential()
if credential:
    print(f"I got a credential! {credential}")

servicebus_client = ServiceBusClient(fully_qualified_namespace=FULLY_QUALIFIED_NAMESPACE, credential=credential)

if servicebus_client:
    print(f"I got a client! {servicebus_client}")

with servicebus_client:
    receiver = servicebus_client.get_queue_receiver(queue_name=QUEUE_NAME)
    with receiver:
        received_msgs = receiver.receive_messages(max_message_count=10, max_wait_time=5)
        for msg in received_msgs:
            print(str(msg))
            receiver.complete_message(msg)

print("Done!")