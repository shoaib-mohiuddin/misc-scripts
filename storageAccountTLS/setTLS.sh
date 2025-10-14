#!/bin/bash

# Input CSV file
input_file="storageaccount.csv"

# Output log file
output_file="tls_enforcement_results.csv"

# Write header to output file
echo "StorageAccountName,ResourceGroupName,Status,Timestamp" > "$output_file"

# Skip header and process each line
tail -n +2 "$input_file" | while IFS=',' read -r storageAccount resourceGroup
do
    echo "Enforcing TLS 1.2 for: $storageAccount in $resourceGroup"

    az storage account update \
        --name "$storageAccount" \
        --resource-group "$resourceGroup" \
        --min-tls-version TLS1_2

    if [ $? -eq 0 ]; then
        echo "Success: $storageAccount"
        echo "$storageAccount,$resourceGroup,Success,$(date)" >> "$output_file"
    else
        echo "Failed: $storageAccount"
        echo "$storageAccount,$resourceGroup,Failed,$(date)" >> "$output_file"
    fi
done

echo "Results saved to: $output_file"
echo "Batch TLS enforcement completed."
