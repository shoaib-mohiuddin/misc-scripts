import boto3
from library.s3_analyzer import S3_analyzer
from library.ebs.ebs_snapshots_analyzer import ebs_snapshots_analyzer
from library.ebs.ebs_gp2_analyzer import ebs_gp2_analyzer
from library.ebs.ebs_available_volumes_analyzer import ebs_available_volumes_analyzer
from library.ebs.ebs_unencrypted_volumes_analyzer import ebs_unencrypted_volumes_analyzer
from library.ami_analyzer import ami_analyzer
from library.unused_sg import sg_analyzer
from library.classic_elb_analyzer import classic_elb_analyzer
from library.iam_access_keys_analyzer import iam_access_keys_analyzer
from library.ec2_overprovisioned_analyzer import ec2_overprovisioned_analyzer

# Specifiy default region
regions = [
    'us-east-1'
]


# Get User Inputs
def initial_setup():
    regions_list = input(
        "Enter the regions for analyzing (e.g.: us-east-1,eu-west-1)\n").split(',')
    return regions_list

sts = boto3.client('sts')
account_id = sts.get_caller_identity()['Account']

regions = initial_setup()
print("Analyzing for these regions:\n", regions)

# AMI Analyzer
# Creates csv report showing region, age, encryption, and monthly cost
ami = ami_analyzer(account_id)
ami.analyze(regions)

# Creates csv report showing Region, Size, Encryption, age and monthly cost
ebs_snapshots = ebs_snapshots_analyzer(account_id)
ebs_snapshots.analyze(regions)

# Creates csv report for listing GP2 Volumes with required fields
ebs_gp2_volumes = ebs_gp2_analyzer(account_id)
ebs_gp2_volumes.analyze(regions)

# Creates csv report for listing Unattached Volumes with required fields
ebs_available_volumes = ebs_available_volumes_analyzer(account_id)
ebs_available_volumes.analyze(regions)

# Creates csv report for listing Unencrypted Volumes with required fields
ebs_unecrypted_volumes = ebs_unencrypted_volumes_analyzer(account_id)
ebs_unecrypted_volumes.analyze(regions)

# Creates report showing Region, Size, Number of Objects, Potential Costs, Lifecycle Policys, Replication Policies
# Exports: CSV, HTML
s3 = S3_analyzer(account_id)
s3.analyze()

# Creates csv report for listing Unused Security Groups
unused_groups = sg_analyzer(account_id)
unused_groups.analyze(regions)

# Creates csv report for listing Classic Load Balancers with required fields
classic_lbs = classic_elb_analyzer(account_id)
classic_lbs.analyze(regions)

# Creates csv report for listing list of IAM users with access keys older than 90 days
old_access_keys = iam_access_keys_analyzer(account_id)
old_access_keys.analyze()

# Creates csv report for listing overprovisioned EC2 instances using Compute Optimizer
overprovisioned_instances = ec2_overprovisioned_analyzer(account_id)
overprovisioned_instances.analyze(regions)
