"""
AMI Analyzer

This module analyzes AMIs in specified AWS regions and generates a CSV report.
"""

import csv
import datetime
import boto3


class AmiAnalyzer:
    """
    Analyzes AMIs to find details about them, including encryption status, age, and cost.
    """

    def __init__(self, account_id):
        self.account_id = account_id
        self.images = []

    def analyze(self, region_list):
        """
        Analyzes the specified regions for AMIs.
        Args:
            region_list (list): List of AWS regions to analyze.
        """
        print("AMI: Analyzing...")

        # Loop through Regions
        for region in region_list:

            # Pull all AMI's from the region
            ami = boto3.client('ec2', region_name=region)
            images = ami.describe_images(Owners=['self'])['Images']

            # Determine age and cost of each AMI by adding storage
            for image in images:
                image_encryption = False
                image_platform = image['PlatformDetails']
                image_description = ''
                image_id = image['ImageId']
                image_creation_date = image['CreationDate']
                image_creation_date = datetime.datetime.strptime(
                    image_creation_date, '%Y-%m-%dT%H:%M:%S.%fZ')
                image_age = datetime.datetime.now() - image_creation_date

                if 'Description' in image:
                    image_description = image['Description']

                image_storage_cost = 0
                for block_device in image['BlockDeviceMappings']:
                    if 'Ebs' in block_device:
                        image_storage_cost += block_device['Ebs']['VolumeSize'] * 0.05
                    if 'Encrypted' in block_device:
                        image_encryption = block_device['Encrypted']

                self.images.append({
                    'Account ID': self.account_id,
                    'Region': region,
                    'Name': image['Name'],
                    'Description': image_description,
                    'Platform': image_platform,
                    'ImageId': image_id,
                    'ImageCost': image_storage_cost,
                    'ImageAge': image_age.days,
                    'ImageEncryption': image_encryption,
                })
        self.csv()

    def csv(self):
        """
        Write CSV
        """
        with open(f'ami_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'Region', 'Name', 'Description', 'Platform',
                          'ImageId', 'ImageCost', 'ImageAge', 'ImageEncryption']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for image in self.images:
                writer.writerow(image)
