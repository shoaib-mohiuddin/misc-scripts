#!/bin/bash

# Input file from the enforcement script
input_file="tls_enforcement_results_sanonprod.csv"

# Output file for rollback results
output_file="tls_rollback_results_sanonprod.csv"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo -e "${RED}Error: Input file '$input_file' not found!${NC}"
    echo "Please ensure the TLS enforcement results file exists."
    exit 1
fi

# Write header for rollback results
echo "SubscriptionName,ResourceGroup,StorageAccount,CurrentTLS,RolledBackTLS,Status,ErrorMessage,Timestamp" > "$output_file"

current_subscription=""
rollback_count=0
skip_count=0

echo "================================"
echo "TLS ROLLBACK SCRIPT"
echo "================================"
echo ""
echo -e "${YELLOW}WARNING: This will revert TLS settings to their previous versions.${NC}"
echo "Press Enter to continue or Ctrl+C to cancel..."
read

echo ""
echo "Starting rollback process..."
echo ""

while IFS=',' read -r subscriptionName resourceGroup storageAccount previousTLS newTLS status errorMessage timestamp
do
    # Skip header and failed entries from original run
    if [ "$subscriptionName" = "SubscriptionName" ] || [ "$status" != "Success" ]; then
        continue
    fi
    
    # Remove quotes, newlines, carriage returns, and trim whitespace
    subscriptionName=$(echo "$subscriptionName" | tr -d '"\r\n' | xargs)
    resourceGroup=$(echo "$resourceGroup" | tr -d '"\r\n' | xargs)
    storageAccount=$(echo "$storageAccount" | tr -d '"\r\n' | xargs)
    previousTLS=$(echo "$previousTLS" | tr -d '"\r\n' | xargs)
    newTLS=$(echo "$newTLS" | tr -d '"\r\n' | xargs)
    
    echo "================================"
    echo "Processing: $storageAccount"
    echo "Subscription: $subscriptionName"
    
    # Skip if previous TLS was already TLS1_2 or not set
    if [ "$previousTLS" = "TLS1_2" ] || [ "$previousTLS" = "Not Set" ]; then
        echo -e "${YELLOW}⊘ Skipping: Previous TLS was already TLS1_2 or not set${NC}"
        echo "$subscriptionName,$resourceGroup,$storageAccount,$newTLS,$previousTLS,Skipped,Already at TLS1_2 or not set,$(date)" >> "$output_file"
        skip_count=$((skip_count + 1))
        echo ""
        continue
    fi
    
    # Get subscription ID from Azure (if needed)
    # For now, assuming we need to find it or it's stored somewhere
    # You may need to adjust this part based on your subscription ID format
    
    # Switch subscription if needed
    if [ "$subscriptionName" != "$current_subscription" ]; then
        echo "Switching to subscription: $subscriptionName"
        az account set --subscription "$subscriptionName"
        if [ $? -eq 0 ]; then
            current_subscription="$subscriptionName"
        else
            echo -e "${RED}Failed to switch to subscription: $subscriptionName${NC}"
            echo "$subscriptionName,$resourceGroup,$storageAccount,$newTLS,N/A,Failed,Subscription switch failed,$(date)" >> "$output_file"
            continue
        fi
    fi
    
    # Get current TLS version to verify
    echo "Checking current TLS version..."
    current_tls=$(az storage account show \
        --name "$storageAccount" \
        --resource-group "$resourceGroup" \
        --query "minimumTlsVersion" \
        --output tsv 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to retrieve current TLS version${NC}"
        error_msg=$(echo "$current_tls" | tr -d '\n' | tr '"' "'")
        echo "$subscriptionName,$resourceGroup,$storageAccount,Unknown,N/A,Failed,$error_msg,$(date)" >> "$output_file"
        echo ""
        continue
    fi
    
    if [ -z "$current_tls" ] || [ "$current_tls" = "null" ]; then
        current_tls="Not Set"
    fi
    
    echo "Current TLS: $current_tls"
    echo "Rolling back to: $previousTLS"
    
    # Rollback to previous TLS version
    echo "Reverting TLS version..."
    error_output=$(az storage account update \
        --name "$storageAccount" \
        --resource-group "$resourceGroup" \
        --min-tls-version "$previousTLS" 2>&1)
    
    if [ $? -eq 0 ]; then
        # Verify rollback
        rolled_back_tls=$(az storage account show \
            --name "$storageAccount" \
            --resource-group "$resourceGroup" \
            --query "minimumTlsVersion" \
            --output tsv 2>/dev/null)
        
        if [ -z "$rolled_back_tls" ]; then
            rolled_back_tls="$previousTLS"
        fi
        
        echo -e "${GREEN}✓ Success: Rolled back $storageAccount${NC}"
        echo "  $current_tls → $rolled_back_tls"
        echo "$subscriptionName,$resourceGroup,$storageAccount,$current_tls,$rolled_back_tls,Success,,$(date)" >> "$output_file"
        rollback_count=$((rollback_count + 1))
    else
        echo -e "${RED}✗ Failed: $storageAccount${NC}"
        error_msg=$(echo "$error_output" | tr -d '\n' | tr '"' "'")
        echo "$subscriptionName,$resourceGroup,$storageAccount,$current_tls,N/A,Failed,$error_msg,$(date)" >> "$output_file"
    fi
    
    echo ""
done < "$input_file"

echo "================================"
echo "ROLLBACK COMPLETED"
echo "================================"
echo "Results saved to: $output_file"
echo ""

# Display summary
total_processed=$(tail -n +2 "$output_file" | wc -l)
success_count=$(tail -n +2 "$output_file" | grep -c ",Success,")
failed_count=$(tail -n +2 "$output_file" | grep -c ",Failed,")
skipped_count=$(tail -n +2 "$output_file" | grep -c ",Skipped,")

echo "Summary:"
echo "  Total processed: $total_processed"
echo "  Successfully rolled back: $success_count"
echo "  Skipped: $skipped_count"
echo "  Failed: $failed_count"
echo ""

if [ $success_count -gt 0 ]; then
    echo "Rolled Back Storage Accounts:"
    tail -n +2 "$output_file" | grep "Success" | while IFS=',' read -r sub rg sa curr prev status err ts
    do
        echo "  • $sa: $curr → $prev"
    done
fi

echo "================================"