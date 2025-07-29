"""
EC2 Overprovisioned Analyzer

This module analyzes EC2 instances in specified AWS regions to identify overprovisioned instances.
It generates a CSV report with details about each overprovisioned instance, including its ARN, name, 
current instance type, and recommended instance types.
"""

import csv
import boto3


class Ec2OverprovisionedAnalyzer:
    """
    Analyzes EC2 instances to find overprovisioned instances.
    """

    def __init__(self, account_id):
        self.account_id = account_id
        self.overprovisioned_instances = []

    def analyze(self, region_list):
        """
        Analyzes the specified regions for overprovisioned EC2 instances.
        Args:
            region_list (list): List of AWS regions to analyze.
        """
        print("EC2: Analyzing Overprovisioned Instances...")

        # Loop through Regions
        for region in region_list:

            ec2 = boto3.client('compute-optimizer', region_name=region)
            instances = ec2.get_ec2_instance_recommendations()['instanceRecommendations']
            for instance in instances:
                if instance['finding'] == 'OVER_PROVISIONED':
                    # print(instance)
                    self.overprovisioned_instances.append({
                        'Account ID': self.account_id,
                        'Region': region,
                        'Instance ARN': instance['instanceArn'],
                        'Instance Name': instance['instanceName'],
                        'Current Instance Type': instance['currentInstanceType'],
                        'Recommended Instance Type - Option 1': instance['recommendationOptions'][0],
                        # 'Recommended Instance Type - Option 2': instance['recommendationOptions'][1] if len(instance['recommendationOptions']) > 1 else 'N/A'
                    })
        self.csv()

    def csv(self):
        """
        Write CSV  
        """
        with open(f'ec2_overprovisioned_instances_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'Region', 'Instance ARN', 'Instance Name',
                          'Current Instance Type', 'Recommended Instance Type - Option 1',
                          'Recommended Instance Type - Option 2']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for volume in self.overprovisioned_instances:
                writer.writerow(volume)
