"""
EBS Available Volumes Analyzer

This module analyzes EBS volumes in specified AWS regions to identify unattached volumes.
It generates a CSV report with details about each unattached volume.
"""

import csv
import boto3


class EbsAvailableVolumesAnalyzer:
    """
    Analyzes EBS volumes to find unattached volumes.
    """

    def __init__(self, account_id):
        self.account_id = account_id
        self.available_volumes = []

    def analyze(self, region_list):
        """
        Analyzes the specified regions for unattached EBS volumes.
        Args:
            region_list (list): List of AWS regions to analyze.
        """
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
        """
        Write CSV
        """
        with open(f'available_volumes_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'Region', 'Volume ID',
                          'State', 'Type', 'IOPS', 'Size']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for volume in self.available_volumes:
                writer.writerow(volume)
