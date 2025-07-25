from azure.identity import DefaultAzureCredential

from azure.mgmt.compute import ComputeManagementClient



def main():
    client = ComputeManagementClient(
        credential=DefaultAzureCredential(),
        subscription_id="ec057239-e4b9-4f3a-bb91-769e0d722e04",
    )

    response = client.disks.get(
        resource_group_name="RG-DEV-APP-RPA-WE01",
        disk_name="AA-D-TS-WE01_osdisk2",
    )
    # print(response)

    print(f"Encryption Type: {response.encryption.type}")
    # print(f"Encryption Enabled: {response.encryption_settings.enabled}")
    print(f"Disk Size (GB): {response.disk_size_gb}")
    print(f"Disk State: {response.disk_state}")
    print(f"Disk SKU Name: {response.sku.name}")


if __name__ == "__main__":
    main()