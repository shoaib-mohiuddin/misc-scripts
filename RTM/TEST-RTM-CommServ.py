#!/usr/bin/env python3
import sys
import csv
import base64
from azure.communication.email import EmailClient
from azure.identity import DefaultAzureCredential
from azure.mgmt.automation import AutomationClient

# Connect to Azure Automation Account and retrieve the variable value
automation_account_name = "AUTOACC-PROD-IT-OPS"
resource_group_name = "RG-PROD-IT-AUTOMATION-NE01"
subscription_id = "ec057239-e4b9-4f3a-bb91-769e0d722e04"

credential = DefaultAzureCredential()
automation_client = AutomationClient(credential, subscription_id)

variable = automation_client.variable.get(resource_group_name, automation_account_name, "RouteTableReport")
body = variable.value
html_table = (body.encode('ascii').decode('unicode-escape')).replace("@@@", " " )

connection_string = "endpoint=https://autoacc-prod-it-ops-comm-service.europe.communication.azure.com/;accesskey=xxxxxx"
email_client = EmailClient.from_connection_string(connection_string)

email_to = sys.argv[1]
email_from = sys.argv[2]
subject = (sys.argv[3]).replace("@@@", " ")
to_name = sys.argv[4]

message = {
    "content": {
        "subject": subject,
        "plainText": subject,
        "html": html_table
    },
    "recipients": {
        "to": [
            {
                "address": email_to,
                "displayName": to_name
            }
        ]
    },
    "senderAddress": email_from
}

try:
    poller = email_client.begin_send(message)
    result = poller.result()
    print("Email sent successfully.")
except Exception as e:
    print("Error sending email:", str(e))
