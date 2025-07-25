import csv
from azure.mgmt.compute import ComputeManagementClient

class UnencryptedDiskAnalyzer:

  def __init__(self, credential, subs_in_scope):
    self.credential = credential
    self.subs_in_scope = subs_in_scope
    self.unencrypted_disks = []
  
  def analyze(self):
    print("Disks: Analyzing Unencrypted disks...")

    for sub_id, sub_name in self.subs_in_scope:
      compute_client = ComputeManagementClient(self.credential, sub_id)
      disks = compute_client.disks.list()

      for disk in disks:
        if not disk.encryption.type:
          self.unencrypted_disks.append({
            'Subscription Name': sub_name,
            'Subscription ID': sub_id,
            'Resource Group': disk.id.split('/')[4],
            'Disk Name': disk.name,
            'Location': disk.location,
            'Size (GB)': disk.disk_size_gb,
            'Encrypted': 'False'
          })
    
    self.csv()
  
  def csv(self):
    # Write CSV
    with open(f'unencrypted_disks.csv', 'w', newline='') as csvfile:
      fieldnames = ['Subscription Name', 'Subscription ID', 'Resource Group', 'Disk Name', 'Location',
                    'Size (GB)', 'Encrypted']
      writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
      writer.writeheader()
      for disk in self.unencrypted_disks:
        writer.writerow(disk)
