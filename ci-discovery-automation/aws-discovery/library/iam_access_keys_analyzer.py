"""
IAM Access Key Analyzer

This module analyzes IAM access keys in an AWS account to identify keys that are older than 90 days.
It generates a CSV report with details about each old access key, including the user, access key ID, 
status, and creation date.
"""

import csv
import datetime
import boto3


class IamAccessKeyAnalyzer:
    """
    Analyzes IAM access keys to find keys that are older than 90 days.
    """

    def __init__(self, account_id):
        self.account_id = account_id
        self.iam_access_keys = []

    def analyze(self):
        """
        Analyzes the IAM access keys in the account.
        This method retrieves all IAM users and their access keys, checking if any keys are older than 90 days.
        """
        print("IAM: Analyzing Old Access Keys...")

        resource = boto3.resource('iam')
        client = boto3.client('iam')
        today = datetime.datetime.now()

        # For every user
        for user in resource.users.all():
            # Get Access Keys for the User
            keys_response = client.list_access_keys(UserName=user.user_name)

            # For every Access Key associate with the user
            for key in keys_response['AccessKeyMetadata']:
                access_key_id = key['AccessKeyId']
                username = key['UserName']
                status = key['Status']
                CreateDate = (
                    today - key['CreateDate'].replace(tzinfo=None)).days

                if CreateDate > 90:
                    self.iam_access_keys.append({
                        'Account ID': self.account_id,
                        'User': username,
                        'Access Key Id': access_key_id,
                        'Access Key Status': status,
                        'Created': CreateDate
                    })
        self.csv()

    def csv(self):
        """
        Write CSV
        """
        with open(f'iam_old_access_keys_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'User', 'Access Key Id',
                          'Access Key Status', 'Created']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for accesskeys in self.iam_access_keys:
                writer.writerow(accesskeys)
