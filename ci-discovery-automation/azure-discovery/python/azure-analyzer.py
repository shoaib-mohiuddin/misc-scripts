from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import SubscriptionClient
from library.disk.standard_ssd_disks_analyzer import StandardSSDDiskAnalyzer
from library.disk.unattached_disks_analyzer import UnattachedDiskAnalyzer
from library.disk.unencrypted_disks_analyzer import UnencryptedDiskAnalyzer

credential = DefaultAzureCredential()

def get_subscription_map(credential):
    sub_client = SubscriptionClient(credential)
    return {sub.subscription_id: sub.display_name for sub in sub_client.subscriptions.list()}

def initial_setup(sub_map):
    raw = input("Enter Subscription IDs or Names (comma-separated):\n").split(',')
    subs = [s.strip() for s in raw]

    resolve = []
    for s in subs:
        # Match by ID or name
        matched = [(sid, name) for sid, name in sub_map.items() if s == sid or s.lower() == name.lower()]
        if matched:
            resolve.append(matched[0])
        else:
            print(f"Subscription '{s}' not found in your tenant.")
    return resolve

sub_map = get_subscription_map(credential)
subs_in_scope = initial_setup(sub_map)
print("Analyzing for these subscriptions:\n", [f"{name} ({sid})" for sid, name in subs_in_scope])

# standard_ssd_analyzer = StandardSSDDiskAnalyzer(credential, subs_in_scope)
# standard_ssd_analyzer.analyze()

# unattached_disk_analyzer = UnattachedDiskAnalyzer(credential, subs_in_scope)
# unattached_disk_analyzer.analyze()

unencrypted_disk_analyzer = UnencryptedDiskAnalyzer(credential, subs_in_scope)
unencrypted_disk_analyzer.analyze()