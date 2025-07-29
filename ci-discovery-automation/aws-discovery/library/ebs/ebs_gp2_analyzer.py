"""
EBS GP2 Analyzer

This module analyzes EBS GP2 volumes in specified AWS regions and generates a CSV report
with details about each GP2 volume, including its ID, size, IOPS, and attached instances.
"""

import csv
import boto3


class EbsGp2Analyzer:
    """
    Analyzes EBS volumes to find GP2 volumes.
    """

    def __init__(self, account_id):
        self.account_id = account_id
        self.gp2_volumes = []

    def analyze(self, region_list):
        """
        Analyzes the specified regions for GP2 EBS volumes.
        Args:
            region_list (list): List of AWS regions to analyze.
        """
        print("EBS: Analyzing GP2 volumes...")

        # Loop through Regions
        for region in region_list:

            ebs = boto3.client('ec2', region_name=region)
            volumes = ebs.describe_volumes()['Volumes']

            for volume in volumes:
                volume_id = volume['VolumeId']
                volume_type = volume['VolumeType']
                volume_state = volume['State']
                volume_size = volume['Size']
                vol_attachments = ''
                iops = ''
                if volume_type == 'gp2':
                    if volume_state == 'in-use':
                        vol_attachments = volume['Attachments'][0]['InstanceId']
                    iops = volume['Iops']
                    self.gp2_volumes.append({
                        'Account ID': self.account_id,
                        'Region': region,
                        'Volume ID': volume_id,
                        'Type': volume_type,
                        'Attached Instances': vol_attachments,
                        'IOPS': iops,
                        'Size': volume_size
                    })
        self.csv()

    def csv(self):
        """
        Write CSV
        """
        with open(f'ebs_gp2_volumes_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'Region', 'Volume ID', 'Type',
                          'Size', 'IOPS', 'Attached Instances']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for volume in self.gp2_volumes:
                writer.writerow(volume)
