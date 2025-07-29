"""
S3 Analyzer

This module analyzes S3 buckets in specified AWS regions to gather information about bucket size, item count, 
encryption, versioning, lifecycle policies, replication, and public access status.
It generates a CSV report with details about each bucket.
"""

import csv
import datetime
import boto3
import botocore


# Create S3 Class
class S3Analyzer:
    """
    Analyzes S3 buckets to gather information such as size, item count, encryption, versioning, lifecycle policies,
    replication, and public access status."""

    def __init__(self, account_id):
        self.account_id = account_id
        self.s3_client = boto3.client('s3')
        self.all_buckets = []

    def analyze(self, mode='light'):
        """
        Analyzes the specified regions for S3 buckets.
        Args:
            mode (str): Mode of analysis, either 'light' for a quick scan(default) or 'full' for a deep analysis.
        """
        print("S3: Analyzing...")
        if mode == 'light':
            self.light_scan()
            self.csv()
        elif mode == 'full':
            self.deep_analyze()
            self.deep_csv()

    def light_scan(self):
        """
        Performs a light scan of S3 buckets to gather basic information such as size, item count, encryption, 
        versioning, lifecycle policies, replication, and public access status.
        """
        # Initialize AWS credentials and S3 client
        s3_client = boto3.client('s3')

        # List all S3 buckets in the account
        s3_buckets = s3_client.list_buckets()['Buckets']

        # Generate a region list for scanning Cloudwatch
        region_list = []

        for bucket in s3_buckets:
            bucket_location = s3_client.get_bucket_location(
                Bucket=bucket['Name'])['LocationConstraint']

            # Work around for USE1 buckets
            if bucket_location is None:
                bucket_location = 'us-east-1'

            # some of the buckets show EU as location constraint whereas they exist in eu-west-1
            if bucket_location == 'EU':
                bucket_location = 'eu-west-1'

            if bucket_location not in region_list and bucket_location is not None:
                region_list.append(bucket_location)

            # print(bucket_location)
            # print(region_list)

        # Loop through Regions
        for region in region_list:
            # Init Cloudwatch Client
            cw_client = boto3.client('cloudwatch', region_name=region)

            # Scan CW for all buckets in each region
            for bucket in s3_buckets:
                # Get Cloudwatch Metrics for each bucket

                bucket_name = bucket['Name']
                bucket_size_data = cw_client.get_metric_statistics(
                    Namespace='AWS/S3',
                    MetricName='BucketSizeBytes',
                    Dimensions=[
                        {
                            'Name': 'BucketName',
                            'Value': bucket_name
                        },
                        {
                            'Name': 'StorageType',
                            'Value': 'StandardStorage'
                        }
                    ],
                    StartTime=datetime.datetime.now() - datetime.timedelta(days=2),
                    EndTime=datetime.datetime.now(),
                    Period=43200,
                    Statistics=['Average']
                )

                bucket_count_data = cw_client.get_metric_statistics(
                    Namespace='AWS/S3',
                    MetricName='NumberOfObjects',
                    Dimensions=[
                        {
                            'Name': 'BucketName',
                            'Value': bucket_name
                        },
                        {
                            'Name': 'StorageType',
                            'Value': 'AllStorageTypes'
                        }
                    ],
                    StartTime=datetime.datetime.now() - datetime.timedelta(days=2),
                    EndTime=datetime.datetime.now(),
                    Period=43200,
                    Statistics=['Average']
                )

                # If we found the bucket in cloudwatch, get the encryption and versioning status
                if 'Datapoints' in bucket_size_data and len(bucket_size_data['Datapoints']) > 0:
                    bucket_size = bucket_size_data['Datapoints'][0]['Average']

                    # Assuming there are objects and data from cloudwatch if there is size data.
                    if len(bucket_count_data['Datapoints']) > 0:
                        bucket_count = bucket_count_data['Datapoints'][0]['Average']
                    else:
                        bucket_count = 0

                    # Get Bucket Details before checking size and object count
                    # Get bucket encryption
                    enc_res = s3_client.get_bucket_encryption(Bucket=bucket['Name'])[
                        "ServerSideEncryptionConfiguration"]
                    bucket_encryption = str(enc_res['Rules'][0]['ApplyServerSideEncryptionByDefault']
                                            ['SSEAlgorithm']) + "|" + str(enc_res['Rules'][0]['BucketKeyEnabled'])

                    # Get bucket versioning
                    version_res = s3_client.get_bucket_versioning(
                        Bucket=bucket['Name'])
                    # print(version_res)
                    if 'Status' in version_res:
                        bucket_versioning = version_res['Status']
                    else:
                        bucket_versioning = 'Disabled'

                    # Get Lifecycle Policies
                    try:
                        lifecycle_res = s3_client.get_bucket_lifecycle_configuration(
                            Bucket=bucket['Name'])
                        if 'Rules' in lifecycle_res:
                            bucket_lifecycle = 'Enabled'
                    except botocore.exceptions.ClientError as e:
                        if e.response['Error']['Code'] == 'NoSuchLifecycleConfiguration':
                            bucket_lifecycle = ''

                    # Get replication configuration
                    try:
                        replication_res = s3_client.get_bucket_replication(
                            Bucket=bucket['Name'])
                        if 'ReplicationConfiguration' in replication_res:
                            bucket_replication = 'Enabled'
                    except botocore.exceptions.ClientError as e:
                        if e.response['Error']['Code'] == 'ReplicationConfigurationNotFoundError':
                            bucket_replication = ''

                    # Check if bucket is public
                    # Check Policy, and block public access
                    bucket_public = 'Public'
                    try:
                        pab_res = s3_client.get_public_access_block(
                            Bucket=bucket['Name'])
                        if pab_res['PublicAccessBlockConfiguration']['BlockPublicAcls'] is True and pab_res['PublicAccessBlockConfiguration']['BlockPublicPolicy'] is True:
                            bucket_public = 'Private'
                    except botocore.exceptions.ClientError as e:
                        print("Exception: {}".format(type(e).__name__))
                        # Check Policy
                        try:
                            policy_res = s3_client.get_bucket_policy_status(
                                Bucket=bucket['Name'])
                            if policy_res['PolicyStatus']['IsPublic'] is False:
                                bucket_public = 'Private'
                        except botocore.exceptions.ClientError as e:
                            print("Exception: {}".format(type(e).__name__))
                            bucket_public = 'Public'

                    # Save the bucket information
                    self.all_buckets.append({
                        'Account ID': self.account_id,
                        'Region': region,
                        'BucketName': bucket_name,
                        'BucketSize': bucket_size / (1024 ** 3),
                        'BucketItems': bucket_count,
                        'BucketCost': (bucket_size / (1024 ** 3)) * 0.023,
                        'BucketGlacier': (bucket_size / (1024 ** 3)) * 0.004,
                        'BucketEncryption': bucket_encryption,
                        'BucketVersioning': bucket_versioning,
                        'BucketLifecycle': bucket_lifecycle,
                        'BucketReplication': bucket_replication,
                        'BucketPublic': bucket_public})

    def csv(self):
        """
        Export CSV of bucket data
        """

        with open(f's3_{self.account_id}.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['Account ID', 'Region', 'BucketName', 'BucketSize', 'BucketItems', 'BucketCost', 'BucketGlacier',
                          'BucketEncryption', 'BucketVersioning', 'BucketLifecycle', 'BucketReplication', 'BucketPublic']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for bucket in self.all_buckets:
                writer.writerow(bucket)

    def deep_analyze(self):
        """
        Deep Mode has a closer look at the bucket items and determines a more accurate cost of the bucket per item and 
        storage tier, this does take longer and uses the S3 list object API, if a bucket has millions of items this 
        could start to incur cost for clients as the API can only return 1000 items per list request. 
        This is not the default run mode for this reason and should be used only as needed.
        """
        # Initialize AWS credentials and S3 client
        s3_client = boto3.client('s3')

        # List all S3 buckets in the account
        response = s3_client.list_buckets()
        buckets = response['Buckets']

        # Calculate potential cost savings based on object age and storage type
        current_date = datetime.datetime.now().astimezone()

        # AWS S3 Tier Cost table: https://aws.amazon.com/s3/pricing/
        aws_s3_pricing = {
            'STANDARD': 0.023,
            'INTELLIGENT_TIERING': 0.023,
            'STANDARD_IA': 0.0125,
            'ONEZONE_IA': 0.01,
            'GLACIER_IR': 0.010,
            'GLACIER': 0.004,
            'DEEP_ARCHIVE': 0.00099
        }

        for bucket in buckets:
            bucket_name = bucket['Name']
            print(f"Processing bucket: {bucket_name}")

            # Total Cost of the bucket as an object so we can store each tier's cost
            bucket_cost = {
                'STANDARD': 0.0,
                'INTELLIGENT_TIERING': 0.0,
                'STANDARD_IA': 0.0,
                'ONEZONE_IA': 0.0,
                'GLACIER_IR': 0.0,
                'GLACIER': 0.0,
                'DEEP_ARCHIVE': 0.0
            }

            bucket_items = {
                'STANDARD': 0,
                'INTELLIGENT_TIERING': 0,
                'STANDARD_IA': 0,
                'ONEZONE_IA': 0,
                'GLACIER_IR': 0,
                'GLACIER': 0,
                'DEEP_ARCHIVE': 0
            }

            total_items = 0
            total_cost = 0
            total_size = 0

            # Get S3 bucket lifecycle
            try:
                lifecycle = s3_client.get_bucket_lifecycle_configuration(Bucket=bucket_name,)[
                    'Rules'][0]['ID']
            except botocore.exceptions.ClientError as e:
                print("Exception: {}".format(type(e).__name__))
                lifecycle = "No"

            # Loop through all items in the bucket using continuation tokens
            continuation_token = None

            while True:

                if continuation_token:
                    objects = s3_client.list_objects_v2(
                        Bucket=bucket_name, ContinuationToken=continuation_token)
                else:
                    objects = s3_client.list_objects_v2(Bucket=bucket_name)

                print(".", end="", flush=True)

                if 'Contents' in objects:
                    # Add up the whole bucket cost

                    for obj in objects['Contents']:
                        total_items += len(obj)
                        last_modified = obj['LastModified']
                        storage_class = obj['StorageClass']

                        # Calculate the age of the object
                        # print(f" - {key} - {storage_class} - {last_modified}")
                        age = (current_date - last_modified).days

                        # Convert Object size from Bytes to GB
                        obj['Size'] = obj['Size'] / 1024 / 1024 / 1024
                        total_size += obj['Size']

                        # # Store base cost of object
                        current_cost = obj['Size'] * \
                            aws_s3_pricing[storage_class]
                        total_cost += current_cost

                        # Track how many items are in each tier
                        bucket_items[storage_class] += 1

                        # If age is greater than 90 days then calculate the potential savings for each storage tier calculate the total for the bucket for each tier
                        if age >= 90:
                            # Loop through all pricing tiers and calculate pricing differences
                            for tier in aws_s3_pricing:
                                # If the current Tier is the current object's tier then the cost is 0
                                if tier == storage_class:
                                    bucket_cost[tier] += 0
                                # If Tier is higher than the current tier then add the difference in cost to the cost of the tier
                                else:
                                    bucket_cost[tier] += obj['Size'] * \
                                        (aws_s3_pricing[storage_class] -
                                         aws_s3_pricing[tier])

                # check for truncated objects and grab continuation token
                if objects.get('IsTruncated', False):
                    continuation_token = objects['NextContinuationToken']
                else:
                    break

            # Store the bucket name and cost in the list of all buckets
            self.all_buckets.append({
                "bucket": bucket_name,
                "items": total_items,
                "size": total_size,
                "cost": total_cost,
                "lifecycle": lifecycle,
                "savings": bucket_cost,
                "itemtotals": bucket_items}
            )
            print("")

        print("Calculating totals for all buckets")
        # Total up each tier seperately for all buckets and store it as a total line in the object
        bucket_totals = {
            'STANDARD': 0.0,
            'INTELLIGENT_TIERING': 0.0,
            'STANDARD_IA': 0.0,
            'ONEZONE_IA': 0.0,
            'GLACIER_IR': 0.0,
            'GLACIER': 0.0,
            'DEEP_ARCHIVE': 0.0
        }
        bucket_item_totals = {
            'STANDARD': 0,
            'INTELLIGENT_TIERING': 0,
            'STANDARD_IA': 0,
            'ONEZONE_IA': 0,
            'GLACIER_IR': 0,
            'GLACIER': 0,
            'DEEP_ARCHIVE': 0
        }
        item_total = 0
        size_total = 0
        cost_total = 0

        for bucket in self.all_buckets:
            for tier in bucket['savings']:
                bucket_totals[tier] += bucket['savings'][tier]
            for tier in bucket['itemtotals']:
                bucket_item_totals[tier] += bucket['itemtotals'][tier]
            item_total += bucket['items']
            size_total += bucket['size']
            cost_total += bucket['cost']

        # Sort buckets by cost
        self.all_buckets.sort(key=lambda x: x['cost'], reverse=True)

        self.all_buckets.append({
            "bucket": "Total",
            "items": item_total,
            "size": size_total,
            "cost": cost_total,
            "lifecycle": "",
            "savings": bucket_totals,
            "itemtotals": bucket_item_totals})

    def deep_csv(self):
        """
        Generate CSV Data and export
        """
        print("Generating CSV Data")
        csv_data = []
        for bucket in self.all_buckets:
            csv_data.append(
                [
                    bucket['bucket'],
                    bucket['items'],
                    bucket['size'],
                    bucket['cost'],
                    bucket['lifecycle'],
                    bucket['itemtotals']['STANDARD'],
                    bucket['savings']['STANDARD'],
                    bucket['itemtotals']['INTELLIGENT_TIERING'],
                    bucket['savings']['INTELLIGENT_TIERING'],
                    bucket['itemtotals']['STANDARD_IA'],
                    bucket['savings']['STANDARD_IA'],
                    bucket['itemtotals']['ONEZONE_IA'],
                    bucket['savings']['ONEZONE_IA'],
                    bucket['itemtotals']['GLACIER_IR'],
                    bucket['savings']['GLACIER_IR'],
                    bucket['itemtotals']['GLACIER'],
                    bucket['savings']['GLACIER'],
                    bucket['itemtotals']['DEEP_ARCHIVE'],
                    bucket['savings']['DEEP_ARCHIVE']
                ]
            )

        with open('s3.csv', 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow([
                "Bucket",
                "Items",
                "Size (GB)",
                "Cost",
                "Lifecycle",
                "STANDARD Items",
                "STANDARD",
                "INTELLIGENT_TIERING Items",
                "INTELLIGENT_TIERING",
                "STANDARD_IA Items",
                "STANDARD_IA",
                "ONEZONE_IA Items",
                "ONEZONE_IA",
                "GLACIER IR Items",
                "GLACIER IR",
                "GLACIER Items",
                "GLACIER",
                "DEEP_ARCHIVE Items",
                "DEEP_ARCHIVE"]
            )
            writer.writerows(csv_data)
