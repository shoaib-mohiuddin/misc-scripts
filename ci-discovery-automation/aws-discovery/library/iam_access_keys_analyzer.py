import boto3
import datetime
import csv


class iam_access_keys_analyzer:

    def __init__(self, account_id):
        self.account_id = account_id
        self.iam_access_keys = []

    def analyze(self):
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
        # Write CSV
        with open(f'iam_old_access_keys_{self.account_id}.csv', 'w', newline='') as csvfile:
            fieldnames = ['Account ID', 'User', 'Access Key Id',
                          'Access Key Status', 'Created']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for accesskeys in self.iam_access_keys:
                writer.writerow(accesskeys)
