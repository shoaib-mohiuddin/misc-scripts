import pandas as pd
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.subscription import SubscriptionClient
import logging
from azure.core.exceptions import ResourceNotFoundError

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s', filename='volume_deletion.log', filemode='w')
logging.getLogger('azure.core.pipeline.policies.http_logging_policy').setLevel(logging.WARNING)

# Read the CSV file
csv_file = 'delete_volume_file.csv'
df = pd.read_csv(csv_file)

# Authenticate with Azure
credential = DefaultAzureCredential()
subscription_client = SubscriptionClient(credential)

subscription_name_to_id = {}

# Get subscription ID from name
def get_subscription_id(subscription_name):
    if subscription_name in subscription_name_to_id:
        return subscription_name_to_id[subscription_name]
    for subscription in subscription_client.subscriptions.list():
        if subscription.display_name == subscription_name:
            subscription_name_to_id[subscription_name] = subscription.subscription_id
            return subscription.subscription_id
    raise ValueError(f"Subscription '{subscription_name}' not found")

# Cache compute clients to avoid multiple authentications
compute_clients = {}

# Get the compute client for a subscription
def get_compute_client(subscription_name):
    if subscription_name in compute_clients:
        return compute_clients[subscription_name]
    subscription_id = get_subscription_id(subscription_name)
    compute_client = ComputeManagementClient(credential, subscription_id)
    compute_clients[subscription_name] = compute_client
    return compute_client

# Delete the volume
def delete_volume(subscription_name, resource_group_name, volume_name):
    try:
        compute_client = get_compute_client(subscription_name)
        
        # Check if the volume exists
        try:
            volume = compute_client.disks.get(resource_group_name, volume_name)
        except ResourceNotFoundError:
            logging.info(f"Volume: {volume_name} not found in subscription: {subscription_name}, resource group: {resource_group_name}")
            return False

        # Delete the volume if it exists
        async_volume_delete = compute_client.disks.begin_delete(resource_group_name, volume_name)
        async_volume_delete.result()  # Wait for the operation to complete
        logging.info(f"Deleted volume: {volume_name} in subscription: {subscription_name}, resource group: {resource_group_name}")
        return True
    except Exception as e:
        logging.error(f"Failed to delete volume: {volume_name} in subscription: {subscription_name}, resource group: {resource_group_name}. Error: {e}")
        return False

volumes_deleted = False

# Loop through the CSV file and delete the volumes
for index, row in df.iterrows():
    if delete_volume(row['Subscription Name'], row['Resource Group Name'], row['Disk Name']):
        volumes_deleted = True

if volumes_deleted:
    logging.info("Volume deletion complete.")
else:
    logging.info("No volumes were deleted.")
