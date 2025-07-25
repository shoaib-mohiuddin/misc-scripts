# AWS Analyzer Scripts
These scripts are meant to pull information from multiple areas into a single or multiple reports to assist with identifying CI improvements, they are not meant to be the "answer" to the CI tasks but to be used as a tool to help in identifying those tasks that are useful for the client

Each report is its own Python class within the library folder so the reports can be commented out in the main analyzer file if they are not required, this allows any future reporting to be added in a more modular fashion as well as picking and choosing what to run.

Each report generates its own .CSV file generally using the format "reportname.csv" IE s3.csv

## Prerequisites
This does not use stored credentials and uses whatever credentials you are currently using on the CLI so be sure to assume another role or set the right profile to default for the AWS CLI tools

Make sure a boto3 compatible Python version is installed for running these.

You have AWS CLI installed and working
You are able to switch roles to specific customer AWS accounts via CLI

### EBS Reports
Snapshots: General report that shows the age of EBS snapshots, currently supports multi-region but not multi-account
GP2 Volumes : List of GP2 volumes that can be migrated to GP3
Unencrypted Volumes: List of volumes without encryption
Available Volumes: List of unattached volumes

### AMI Report
A general report that shows the age of AMIs currently supports multi-region but not multi-account

### S3 Analyzer
S3 analyzer scans all buckets, Lite mode reports the following information general information
The region, Name, Size, Item Count, Estimated cost, and Estimated cost if it was glacier.
Additional Information reported
- Encryption
- Versioning
- Lifecycle
- Replication
- Public Access

Deep Mode has a closer look at the bucket items and determines a more accurate cost of the bucket per item and storage tier, this does take longer and uses the S3 list object API, if a bucket has millions of items this could start to incur cost for clients as the API can only return 1000 items per list request
This is not the default run mode for this reason and should be used only as needed.

### Unused Security Groups
Generates a list of security groups that are not attached to any EC2 instance or network interface

### Classic ELBs
Generates a list of classic Load Balancers with required fields.

### IAM Access Keys
Generates a list of access keys that are older than 90 days with their status.

### EC2 OverProvisioned Instances
Generates a list of overprovisioned instances using Compute Optimizer
