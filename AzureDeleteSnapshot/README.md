### Pre-requisites:

Ensure to install below dependencies:
```
pip install pandas azure-identity azure-mgmt-compute azure-mgmt-subscription
```

### Instructions for Running the Scripts:
1. Clone the repo and create a new branch using command `git checkout -b YOUR_BRANCH_NAME`
2. Make sure you are in the **AzureDeleteSnapshot** directory
3. **IMPORTANT:** Update the list of snapshot in the *snapshots.csv* file. For the script to work, the csv file should be in below format  (because the script was authored keeping in mind the incident INC0329387):
```
Snapshot Name,Time Created,Subscription Name,Resource Group Name
snapshot1,2023-06-01T12:34:56,subscription-id-1,resource-group-1
snapshot2,2023-06-02T12:34:56,subscription-id-2,resource-group-2
```
4. Login to the Azure portal from the terminal by running `az login`
5. Execute the Python script
```
python azure_delete_snap.py
```