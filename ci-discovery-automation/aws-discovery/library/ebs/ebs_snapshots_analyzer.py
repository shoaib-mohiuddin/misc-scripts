import boto3
import datetime
import csv


class ebs_snapshots_analyzer:

    def __init__(self, account_id):
        self.account_id = account_id
        self.snapshots = []

    def analyze(self, region_list):
        print("EBS: Analyzing...")

        # Loop through Regions
        for region in region_list:

            ebs = boto3.client('ec2', region_name=region)
            snapshots = ebs.describe_snapshots(OwnerIds=['self'])['Snapshots']

            for snapshot in snapshots:
                snapshot_id = snapshot['SnapshotId']
                snapshot_start_time = snapshot['StartTime']
                snapshot_start_time = snapshot_start_time.replace(tzinfo=None)
                snapshot_age = datetime.datetime.now() - snapshot_start_time
                snapshotkeys = str(snapshot)
                storage_tier = ''
                if snapshotkeys.find('StorageTier') > -1:
                    storage_tier = snapshot['StorageTier']
                self.snapshots.append({
                    'Account ID': self.account_id,
                    'Region': region,
                    'SnapshotId': snapshot_id,
                    'SnapshotSize': snapshot['VolumeSize'],
                    'SnapshotCost ($)': snapshot['VolumeSize'] * 0.05,  # Standard pricing is - $0.05/GB-month
                    'SnapshotAge (Days)': snapshot_age.days,
                    'StorageTier': storage_tier,
                    'SnapshotEncryption': snapshot['Encrypted'],
                })
        self.csv()

    def csv(self):
        # Write CSV
        with open(f'ebs_snapshots_{self.account_id}.csv', 'w', newline='') as csvfile:
            fieldnames = ['Account ID', 'Region', 'SnapshotId', 'SnapshotSize',
                          'SnapshotCost ($)', 'SnapshotAge (Days)', 'StorageTier', 'SnapshotEncryption']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for snapshot in self.snapshots:
                writer.writerow(snapshot)
