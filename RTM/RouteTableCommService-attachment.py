#!/usr/bin/env python3
import sys
import csv
import base64
import io
import json
from azure.communication.email import EmailClient
from azure.identity import DefaultAzureCredential
from azure.mgmt.automation import AutomationClient

# Connect to Azure Automation Account and retrieve the variable value
automation_account_name = "AUTOACC-PROD-IT-OPS"
resource_group_name = "RG-PROD-IT-AUTOMATION-NE01"
subscription_id = "ec057239-e4b9-4f3a-bb91-769e0d722e04"
credential = DefaultAzureCredential()
automation_client = AutomationClient(credential, subscription_id)

# Get the variable value
variable = automation_client.variable.get(resource_group_name, automation_account_name, "RouteTableReport")
raw_data = variable.value

# Parse the JSON string - note that we need to parse it twice because it's double-encoded
data = json.loads(json.loads(raw_data))

# Create CSV file in memory
output = io.StringIO()
if data:
    # Get headers
    headers = list(data[0].keys())
    
    # Create CSV writer
    writer = csv.DictWriter(output, fieldnames=headers)
    
    # Write headers and data
    writer.writeheader()
    writer.writerows(data)

# Get the CSV content and encode it
csv_content = output.getvalue().encode('utf-8')
file_bytes_b64 = base64.b64encode(csv_content)

# Setup email client
connection_string = "endpoint=https://autoacc-prod-it-ops-comm-service.europe.communication.azure.com/;accesskey=xxxxxxx"
email_client = EmailClient.from_connection_string(connection_string)

# Get command line arguments
email_to = sys.argv[1]
email_from = sys.argv[2]
subject = (sys.argv[3]).replace("@@@", " ")
to_name = sys.argv[4]

# Create email message
message = {
    "content": {
        "subject": subject,
        "plainText": subject,
        "html": """
            <html>
                <body>
                    <p>Please find attached the Route Table Compliance Report.</p>
                </body>
            </html>
        """
    },
    "recipients": {
        "to": [
            {
                "address": email_to,
                "displayName": to_name
            }
        ]
    },
    "senderAddress": email_from,
    "attachments": [
        {
            "name": "RouteTableComplianceReport.csv",
            "contentType": "text/csv",
            "contentInBase64": file_bytes_b64.decode()
        }
    ]
}

# Send email
try:
    poller = email_client.begin_send(message)
    result = poller.result()
    print("Email sent successfully.")
except Exception as e:
    print("Error sending email:", str(e))