### Pre-requisites:

Ensure to install below dependencies:
```
pip install pandas azure-identity azure-mgmt-compute azure-mgmt-subscription
```

### Instructions for Running the Scripts:
1. Clone the repo and create a new branch using command `git checkout -b YOUR_BRANCH_NAME`
2. Make sure you are in the **AzureDeleteVolume** directory
3. **IMPORTANT:** Update the list of snapshot in the *delete_volume_file.csv* file. For the script to work, the csv file should be in below format:
```
Volume Name,Subscription Name,Resource Group Name
volume1,subscription-id-1,resource-group-1
volume2,subscription-id-2,resource-group-2
```
4. Login to the Azure portal from the terminal by running `az login`
5. Login through Cloudreach account.
6. Execute the Python script
   The below script checks the disk is in unattached state and delete the disk
```
python volume_delete_unattached.py
```
