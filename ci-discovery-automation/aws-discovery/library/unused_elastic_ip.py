import csv
import boto3

class ElasticIPAnalyzer:
    """
    Analyzes AWS Elastic IPs to find unused Elastic IPs.
    """

    def __init__(self, account_id):
        self.account_id = account_id
        self.unused_ips = []

    def analyze(self, region_list):
        """
        Analyzes the specified regions for unused Elastic IPs.
        Args:
            region_list (list): List of AWS regions to analyze.
        """
        print("Analyzing Unused Elastic IPs...")
        # Loop through Regions
        for region in region_list:
            ec2 = boto3.client('ec2', region_name=region)
            addresses = ec2.describe_addresses()['Addresses']

            for address in addresses:
                if 'InstanceId' not in address and 'NetworkInterfaceId' not in address:
                    self.unused_ips.append({
                        'Account ID': self.account_id,
                        'Region': region,
                        'ElasticIP': address['PublicIp']
                    })
        self.csv()

    def csv(self):
        """
        Write CSV
        """
        with open(f'unused_elastic_ips_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'Region', 'ElasticIP']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for ip in self.unused_ips:
                writer.writerow(ip)