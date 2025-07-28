import csv
from azure.mgmt.compute import ComputeManagementClient

class UnattachedDiskAnalyzer:

  def __init__(self, credential, subs_in_scope):
    self.credential = credential
    self.subs_in_scope = subs_in_scope
    self.unattached_disks = []
  
  def analyze(self):
    print("Disks: Analyzing Unattached disks...")

    for sub_id, sub_name in self.subs_in_scope:
      compute_client = ComputeManagementClient(self.credential, sub_id)
      disks = compute_client.disks.list()

      for disk in disks:
        if disk.disk_state == 'Unattached':
          self.unattached_disks.append({
            'Subscription Name': sub_name,
            'Subscription ID': sub_id,
            'Resource Group': disk.id.split('/')[4],
            'Disk Name': disk.name,
            'Location': disk.location,
            'Disk State': disk.disk_state,
            'Storage Type': disk.sku.name,
            'Size (GB)': disk.disk_size_gb
          })
    
    self.csv()
  
  def csv(self):
    # Write CSV
    with open(f'unattached_disks.csv', 'w', newline='') as csvfile:
      fieldnames = ['Subscription Name', 'Subscription ID', 'Resource Group', 'Disk Name', 'Location',
                    'Disk State', 'Storage Type', 'Size (GB)']
      writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
      writer.writeheader()
      for disk in self.unattached_disks:
        writer.writerow(disk)
