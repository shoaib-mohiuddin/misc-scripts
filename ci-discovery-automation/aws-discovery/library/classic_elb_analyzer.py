import boto3
import csv


class classic_elb_analyzer:

    def __init__(self, account_id):
        self.account_id = account_id
        self.classic_lbs = []

    def analyze(self, region_list):
        print("Analyzing Classic load balancers...")

        # Loop through Regions
        for region in region_list:
            lb = boto3.client('elb', region_name=region)
            classic_lbs = lb.describe_load_balancers()
            for lb in classic_lbs['LoadBalancerDescriptions']:
                # print(lb['LoadBalancerName'], lb['DNSName'], region)
                lb_name = lb['LoadBalancerName']
                lb_type = 'Classic'
                lb_dnsname = lb['DNSName']
                vpc_id = lb['VPCId']
                self.classic_lbs.append({
                    'Account ID': self.account_id,
                    'Region': region,
                    'Load Balancer Name': lb_name,
                    'Type': lb_type,
                    'DNS Name': lb_dnsname,
                    'VPC': vpc_id
                })
        self.csv()

    def csv(self):
        # Write CSV
        with open(f'classic_lbs_{self.account_id}.csv', 'w', newline='') as csvfile:
            fieldnames = ['Account ID', 'Region', 'Load Balancer Name',
                          'Type', 'DNS Name', 'VPC']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for lb in self.classic_lbs:
                writer.writerow(lb)
