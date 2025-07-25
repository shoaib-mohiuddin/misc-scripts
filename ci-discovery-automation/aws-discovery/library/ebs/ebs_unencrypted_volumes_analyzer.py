import boto3
import csv


class ebs_unencrypted_volumes_analyzer:

    def __init__(self, account_id):
        self.account_id = account_id
        self.unencrypted_volumes = []

    def analyze(self, region_list):
        print("EBS: Analyzing Unecrypted volumes...")

        # Loop through Regions
        for region in region_list:
            ebs = boto3.client('ec2', region_name=region)
            volumes = ebs.describe_volumes()['Volumes']

            for volume in volumes:
                volume_id = volume['VolumeId']
                encrypted = volume['Encrypted']
                volume_type = volume['VolumeType']
                volume_state = volume['State']
                volume_size = volume['Size']
                vol_attachments = ''
                iops = ''
                if volume_state == 'in-use':
                    vol_attachments = volume['Attachments'][0]['InstanceId']
                if encrypted is False:
                    self.unencrypted_volumes.append({
                        'Account ID': self.account_id,
                        'Region': region,
                        'Volume ID': volume_id,
                        'Encrypted': encrypted,
                        'Type': volume_type,
                        'Attached Instances': vol_attachments,
                        'IOPS': iops,
                        'Size': volume_size
                    })
        self.csv()

    def csv(self):
        # Write CSV
        with open(f'unencrypted_volumes_{self.account_id}.csv', 'w', newline='') as csvfile:
            fieldnames = ['Account ID', 'Region', 'Volume ID', 'Encrypted',
                          'Type', 'Attached Instances', 'IOPS', 'Size']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for volume in self.unencrypted_volumes:
                writer.writerow(volume)
