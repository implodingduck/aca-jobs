from azure.servicebus import ServiceBusClient
from azure.identity import DefaultAzureCredential


import os
fully_qualified_namespace = os.environ['SERVICEBUS_FULLY_QUALIFIED_NAMESPACE']
queue_name = os.environ['SERVICE_BUS_QUEUE_NAME']

credential = DefaultAzureCredential()
with ServiceBusClient(fully_qualified_namespace, credential) as client:
    with client.get_queue_receiver(queue_name) as receiver:
        for msg in receiver:
            print(str(msg))
            receiver.complete_message(msg)