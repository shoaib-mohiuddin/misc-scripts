"""
Security Group Analyzer

This module analyzes AWS security groups in specified regions to identify unused security groups.
It generates a CSV report with details about each unused security group, its ID and region.
"""

import csv
import boto3


class SecurityGroupAnalyzer:
    """
    Analyzes AWS security groups to find unused security groups.
    """

    def __init__(self, account_id):
        self.account_id = account_id
        self.unused_sgs = []

    def analyze(self, region_list):
        """
        Analyzes the specified regions for unused security groups.
        Args:
            region_list (list): List of AWS regions to analyze.
        """
        print("Analyzing Unused Security Groups...")
        # Loop through Regions
        for region in region_list:
            ec2 = boto3.resource('ec2', region_name=region)
            groups = ec2.security_groups.all()
            interfaces = ec2.network_interfaces.all()
            used_groups = [
                group for interface in interfaces for group in interface.groups]

            for group in groups:
                if group.group_id in [used_group.get('GroupId') for used_group in used_groups]:
                    # Used by network interfaces.
                    continue

                if group.group_id in [pair.get('GroupId') for group in groups
                                      for permission in group.ip_permissions
                                      for pair in permission.get('UserIdGroupPairs', [])]:
                    # Used by other security groups
                    continue

                self.unused_sgs.append({
                    'Account ID': self.account_id,
                    'Region': region,
                    'SGID': group
                })
        self.csv()

    def csv(self):
        """
        Write CSV
        """
        with open(f'unused_sgs_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'Region', 'SGID']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for sg in self.unused_sgs:
                writer.writerow(sg)
