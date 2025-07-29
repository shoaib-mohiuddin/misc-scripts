"""
AWS Discovery Automation Script
This script is entry point for the discovery of various AWS resources
including AMIs, EBS volumes, S3 buckets, security groups, and more.
"""

import boto3
from library.s3_analyzer import S3Analyzer
from library.ebs.ebs_snapshots_analyzer import EbsSnapshotsAnalyzer
from library.ebs.ebs_gp2_analyzer import EbsGp2Analyzer
from library.ebs.ebs_available_volumes_analyzer import EbsAvailableVolumesAnalyzer
from library.ebs.ebs_unencrypted_volumes_analyzer import EbsUnencryptedVolumesAnalyzer
from library.ami_analyzer import AmiAnalyzer
from library.unused_sg import SecurityGroupAnalyzer
from library.classic_elb_analyzer import ClassicElbAnalyzer
from library.iam_access_keys_analyzer import IamAccessKeyAnalyzer
from library.ec2_overprovisioned_analyzer import Ec2OverprovisionedAnalyzer

# Specifiy default region
regions = [
    'us-east-1'
]


# Get User Inputs
def initial_setup():
    """
    Function to get the regions from user input.
    Returns:
        list: List of regions to analyze.
    """
    regions_list = input(
        "Enter the regions for analyzing (e.g.: us-east-1,eu-west-1)\n").split(',')
    return regions_list

sts = boto3.client('sts')
account_id = sts.get_caller_identity()['Account']

regions = initial_setup()
print("Analyzing for these regions:\n", regions)

# AMI Analyzer
# Creates csv report showing region, age, encryption, and monthly cost
ami = AmiAnalyzer(account_id)
ami.analyze(regions)

# Creates csv report showing Region, Size, Encryption, age and monthly cost
ebs_snapshots = EbsSnapshotsAnalyzer(account_id)
ebs_snapshots.analyze(regions)

# Creates csv report for listing GP2 Volumes with required fields
ebs_gp2_volumes = EbsGp2Analyzer(account_id)
ebs_gp2_volumes.analyze(regions)

# Creates csv report for listing Unattached Volumes with required fields
ebs_available_volumes = EbsAvailableVolumesAnalyzer(account_id)
ebs_available_volumes.analyze(regions)

# Creates csv report for listing Unencrypted Volumes with required fields
ebs_unecrypted_volumes = EbsUnencryptedVolumesAnalyzer(account_id)
ebs_unecrypted_volumes.analyze(regions)

# Creates report showing Region, Size, Number of Objects, Potential Costs, Lifecycle Policys, Replication Policies
# Exports: CSV, HTML
s3 = S3Analyzer(account_id)
s3.analyze()

# Creates csv report for listing Unused Security Groups
unused_groups = SecurityGroupAnalyzer(account_id)
unused_groups.analyze(regions)

# Creates csv report for listing Classic Load Balancers with required fields
classic_lbs = ClassicElbAnalyzer(account_id)
classic_lbs.analyze(regions)

# Creates csv report for listing list of IAM users with access keys older than 90 days
old_access_keys = IamAccessKeyAnalyzer(account_id)
old_access_keys.analyze()

# Creates csv report for listing overprovisioned EC2 instances using Compute Optimizer
overprovisioned_instances = Ec2OverprovisionedAnalyzer(account_id)
overprovisioned_instances.analyze(regions)
