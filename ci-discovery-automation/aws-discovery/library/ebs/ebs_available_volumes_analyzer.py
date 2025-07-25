import boto3
import csv


class ebs_available_volumes_analyzer:

    def __init__(self, account_id):
        self.account_id = account_id
        self.available_volumes = []

    def analyze(self, region_list):
        print("EBS: Analyzing Unattached volumes...")

        # Loop through Regions
        for region in region_list:

            ebs = boto3.client('ec2', region_name=region)
            volumes = ebs.describe_volumes()['Volumes']
            for volume in volumes:
                volume_id = volume['VolumeId']
                volume_type = volume['VolumeType']
                volume_state = volume['State']
                volume_size = volume['Size']
                iops = ''
                if volume_state == 'available':
                    iops = volume['Iops']
                    self.available_volumes.append({
                        'Account ID': self.account_id,
                        'Region': region,
                        'Volume ID': volume_id,
                        'Type': volume_type,
                        'State': volume_state,
                        'IOPS': iops,
                        'Size': volume_size
                    })
        self.csv()

    def csv(self):
        # Write CSV
        with open(f'available_volumes_{self.account_id}.csv', 'w', newline='') as csvfile:
            fieldnames = ['Account ID', 'Region', 'Volume ID',
                          'State', 'Type', 'IOPS', 'Size']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for volume in self.available_volumes:
                writer.writerow(volume)
