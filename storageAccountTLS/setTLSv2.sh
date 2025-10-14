#!/bin/bash

# Input CSV file
input_file="export_data (1).csv"
# Output log file
output_file="tls_enforcement_results.csv"

# Write header to output file
echo "SubscriptionName,ResourceGroup,StorageAccount,Status,ErrorMessage,Timestamp" > "$output_file"

# Variable to track current subscription
current_subscription=""

# Skip header and process each line
tail -n +2 "$input_file" | while IFS=',' read -r subscription resourceGroup location resourceName storageAccount subscriptionName
do
    # Remove any quotes and trim whitespace
    subscription=$(echo "$subscription" | tr -d '"' | xargs)
    resourceGroup=$(echo "$resourceGroup" | tr -d '"' | xargs)
    storageAccount=$(echo "$storageAccount" | tr -d '"' | xargs)
    subscriptionName=$(echo "$subscriptionName" | tr -d '"' | xargs)
    
    echo "================================"
    echo "Processing storage account: $storageAccount"
    # echo "Subscription: $subscriptionName ($subscription)"
    # echo "Resource Group: $resourceGroup"
    
    # Switch subscription if different from current
    if [ "$subscription" != "$current_subscription" ]; then
        echo "Switching to subscription: $subscriptionName"
        az account set --subscription "$subscription"
        
        if [ $? -eq 0 ]; then
            current_subscription="$subscription"
            # echo "Successfully switched to subscription: $subscriptionName"
        else
            echo "Failed to switch to subscription: $subscription"
            echo "$subscriptionName,$resourceGroup,$storageAccount,Failed,Subscription switch failed,$(date)" >> "$output_file"
            continue
        fi
    fi
    
    # Enforce TLS 1.2
    echo "Enforcing TLS 1.2..."
    error_output=$(az storage account update \
        --name "$storageAccount" \
        --resource-group "$resourceGroup" \
        --min-tls-version TLS1_2 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "✓ Success: $storageAccount"
        echo "$subscriptionName,$resourceGroup,$storageAccount,Success,,$(date)" >> "$output_file"
    else
        echo "✗ Failed: $storageAccount"
        # Sanitize error message for CSV (remove quotes and newlines)
        error_msg=$(echo "$error_output" | tr -d '\n' | tr '"' "'")
        echo "$subscriptionName,$resourceGroup,$storageAccount,Failed,$error_msg,$(date)" >> "$output_file"
    fi
    
    echo ""
done

echo "================================"
echo "Batch TLS enforcement completed."
echo "Results saved to: $output_file"
echo "================================"

# Display summary
total_count=$(tail -n +2 "$output_file" | wc -l)
success_count=$(tail -n +2 "$output_file" | grep -c ",Success,")
failed_count=$(tail -n +2 "$output_file" | grep -c ",Failed,")

echo "Summary:"
echo "  Total processed: $total_count"
echo "  Successful: $success_count"
echo "  Failed: $failed_count"