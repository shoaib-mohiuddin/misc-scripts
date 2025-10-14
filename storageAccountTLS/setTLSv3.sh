#!/bin/bash

input_file="export_data (1).csv"

output_file="tls_enforcement_results.csv"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Write header
echo "SubscriptionName,ResourceGroup,StorageAccount,PreviousTLS,NewTLS,Status,ErrorMessage,Timestamp" > "$output_file"

current_subscription=""

while IFS=',' read -r subscription resourceGroup location resourceName storageAccount subscriptionName
do
    # Remove quotes, newlines, carriage returns, and trim whitespace
    subscription=$(echo "$subscription" | tr -d '"\r\n' | xargs)
    resourceGroup=$(echo "$resourceGroup" | tr -d '"\r\n' | xargs)
    storageAccount=$(echo "$storageAccount" | tr -d '"\r\n' | xargs)
    subscriptionName=$(echo "$subscriptionName" | tr -d '"\r\n' | xargs)
    
    echo "================================"
    echo "Processing storage account: $storageAccount"
    
    if [ "$subscription" != "$current_subscription" ]; then
        echo "Switching to subscription: $subscriptionName"
        az account set --subscription "$subscription"
        if [ $? -eq 0 ]; then
            current_subscription="$subscription"
        else
            echo "${RED}Failed to switch to subscription: $subscription${NC}"
            echo "$subscriptionName,$resourceGroup,$storageAccount,N/A,N/A,Failed,Subscription switch failed,$(date)" >> "$output_file"
            continue
        fi
    fi
    
    # Get current TLS version
    echo "Checking current TLS version..."
    current_tls=$(az storage account show \
        --name "$storageAccount" \
        --resource-group "$resourceGroup" \
        --query "minimumTlsVersion" \
        --output tsv 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "${RED}✗ Failed to retrieve current TLS version${NC}"
        error_msg=$(echo "$current_tls" | tr -d '\n' | tr '"' "'")
        echo "$subscriptionName,$resourceGroup,$storageAccount,Unknown,N/A,Failed,$error_msg,$(date)" >> "$output_file"
        echo ""
        continue
    fi
    
    # Handle case where TLS version might be empty/null
    if [ -z "$current_tls" ] || [ "$current_tls" = "null" ]; then
        current_tls="Not Set"
    fi
    
    echo "Current TLS version: $current_tls"
    
    # Enforce TLS 1.2
    echo "Enforcing TLS 1.2..."
    error_output=$(az storage account update \
        --name "$storageAccount" \
        --resource-group "$resourceGroup" \
        --min-tls-version TLS1_2 2>&1)
    
    if [ $? -eq 0 ]; then
        # Verify new TLS version
        new_tls=$(az storage account show \
            --name "$storageAccount" \
            --resource-group "$resourceGroup" \
            --query "minimumTlsVersion" \
            --output tsv 2>/dev/null)
        
        if [ -z "$new_tls" ]; then
            new_tls="TLS1_2"
        fi
        
        echo -e "${GREEN}✓ Success: $storageAccount${NC}"
        echo "  Previous TLS: $current_tls → New TLS: $new_tls"
        echo "$subscriptionName,$resourceGroup,$storageAccount,$current_tls,$new_tls,Success,,$(date)" >> "$output_file"
    else
        echo -e "${RED}✗ Failed: $storageAccount${NC}"
        # Sanitize error message for CSV (remove quotes and newlines)
        error_msg=$(echo "$error_output" | tr -d '\n' | tr '"' "'")
        echo "$subscriptionName,$resourceGroup,$storageAccount,$current_tls,N/A,Failed,$error_msg,$(date)" >> "$output_file"
    fi
    
    echo ""
done < <(tail -n +2 "$input_file")

echo "================================"
echo "Script execution completed."
echo "Results saved to: $output_file"
echo "================================"

# # Display summary
# total_count=$(tail -n +2 "$output_file" | wc -l)
# success_count=$(tail -n +2 "$output_file" | grep -c ",Success,")
# failed_count=$(tail -n +2 "$output_file" | grep -c ",Failed,")

# echo "Summary:"
# echo "  Total processed: $total_count"
# echo "  Successful: $success_count"
# echo "  Failed: $failed_count"

# # Show TLS version changes
# echo ""
# echo "TLS Version Changes:"
# tail -n +2 "$output_file" | grep "Success" | while IFS=',' read -r sub rg sa prev new status err ts
# do
#     if [ "$prev" != "$new" ]; then
#         echo "  $sa: $prev → $new"
#     fi
# done