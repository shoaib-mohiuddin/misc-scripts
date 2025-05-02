$resultsarray = @()


$hubVNetiDs = @(

  "/subscriptions/ec057239-e4b9-4f3a-bb91-769e0d722e04/resourceGroups/HyperionIT/providers/Microsoft.Network/virtualNetworks/VNET1-EU-North",
  "/subscriptions/ec057239-e4b9-4f3a-bb91-769e0d722e04/resourceGroups/Hyperion-EUWest/providers/Microsoft.Network/virtualNetworks/VNET1-EU-West",
  "/subscriptions/ec057239-e4b9-4f3a-bb91-769e0d722e04/resourceGroups/RG-PROD-NETWORK-UKS01/providers/Microsoft.Network/virtualNetworks/VNET-PROD-UKS01",
  "/subscriptions/9565839b-cc69-461f-960f-ce4d2949c9a9/resourceGroups/RG-HSL-INFRA-PROD-NETWORK-SA01/providers/Microsoft.Network/virtualNetworks/VNET-HSL-INFRA-PROD-SA01",
  "/subscriptions/9565839b-cc69-461f-960f-ce4d2949c9a9/resourceGroups/RG-HSL-INFRA-PROD-NETWORK-EA01/providers/Microsoft.Network/virtualNetworks/VNET-HSL-INFRA-PROD-EA01",
  "/subscriptions/d1702171-0bdd-4cdf-a38c-773ce0ed4814/resourceGroups/RG-HGS-INFRA-PROD-NETWORK-AE01/providers/Microsoft.Network/virtualNetworks/VNET-HGS-INFRA-PROD-AE01",
  "/subscriptions/aa0ff006-3533-4fa0-871a-f0a822f80d26/resourceGroups/RG-HGS-INFRA-PROD-NETWORK-UC01/providers/Microsoft.Network/virtualNetworks/VNET-HGS-INFRA-PROD-UC01",
  "/subscriptions/aa0ff006-3533-4fa0-871a-f0a822f80d26/resourceGroups/RG-HGS-INFRA-PROD-NETWORK-UE01/providers/Microsoft.Network/virtualNetworks/VNET-HGS-INFRA-PROD-UE01"
)

foreach ($hubVNetiD in $hubVNetiDs){

  $vNet = Get-AzResource -id $hubVNetiD
  $HubSubscription = Select-AzSubscription -SubscriptionId $vNet.ResourceId.split("/")[2] #-Tenant "cb9bec90-76b1-4992-96fe-d8d470564931"
  $hubvNetobj = Get-AzVirtualNetwork -Name $vNet.name -ResourceGroupName $vNet.ResourceGroupName
  $peerings = $hubvNetobj.VirtualNetworkPeerings

  foreach ($peering in $peerings){

    $RemotevNet = Get-AzResource -id $peering.RemoteVirtualNetwork.id
    $SpokeSubscription = Select-AzSubscription -SubscriptionId $RemotevNet.ResourceId.split("/")[2] #-Tenant "cb9bec90-76b1-4992-96fe-d8d470564931"
    $RemotevNetobj = Get-AzVirtualNetwork -Name $RemotevNet.name -ResourceGroupName $RemotevNet.ResourceGroupName

    #$HubSubscription.name.split(" ")[0]
    #$SpokeSubscription = Get-AzSubscription -SubscriptionId $RemotevNet.ResourceId.split("/")[2] -Tenant "cb9bec90-76b1-4992-96fe-d8d470564931"

    $object = [pscustomobject]@{
      HubSubscription = $HubSubscription.name.split(" ")[0]
      hubvNetobj = $hubvNetobj.Name
      SpokeSubscription = $SpokeSubscription.name.split(" ")[0]
      SpokehubvNetobj = $RemotevNetobj.Name
    }

    

    $resultsarray += $object

  }

}

$resultsarray 

# $resultsarray | Export-Csv -Path ".\test.csv" -NoTypeInformation 

# # Extract unique values for each column
# $uniqueHubSubscription = $resultsarray | Select-Object -ExpandProperty HubSubscription | Sort-Object -Unique
# $uniquehubVNetobj = $resultsarray | Select-Object -ExpandProperty hubvNetobj | Sort-Object -Unique
# $uniqueSpokeSubscription = $resultsarray | Select-Object -ExpandProperty SpokeSubscription | Sort-Object -Unique
# $uniqueSpokehubVNetobj = $resultsarray | Select-Object -ExpandProperty SpokehubvNetobj | Sort-Object -Unique

# # Display the unique values
# "-------------------------------------"
# "Unique Hub Subscriptions:"
# "-------------------------------------"
# $uniqueHubSubscription
# "-------------------------------------"
# "Unique Hub VNet Names:"
# "-------------------------------------"
# $uniquehubVNetobj
# "-------------------------------------"
# "Unique Spoke Subscriptions:"
# "-------------------------------------"
# $uniqueSpokeSubscription
# "-------------------------------------"
# "Unique Spoke VNet Names:"
# "-------------------------------------"
# $uniqueSpokehubVNetobj


# # Combine all unique subscriptions into a single object
# $uniqueSubscriptions = $resultsarray | ForEach-Object {
#   $_.HubSubscription
#   $_.SpokeSubscription
# } | Sort-Object -Unique

# # Combine all unique VNets into a single object
# $uniqueVNets = $resultsarray | ForEach-Object {
#   $_.hubvNetobj
#   $_.SpokehubvNetobj
# } | Sort-Object -Unique

# # Display the results
# "-------------------------------------"
# "Unique Subscriptions:"
# "-------------------------------------"
# $uniqueSubscriptions
# "-------------------------------------"
# "Unique vNets:"
# "-------------------------------------"
# $uniqueVNets 
# # @(
# #     "DUAL-RISKWRITE-PREPROD-NE01",
# #     "DUAL-RISKWRITE-PREPROD-WE01",
# #     "DUAL-RISKWRITE-PROD-NE01"
# #     # ...
# # )

# $routeTableNames = @()

# # Dynamically build the 'or' condition
# $condition = ($uniqueVNets | ForEach-Object { "properties.subnets[0].id has '$_'" }) -join " or "

# # Check if $condition is constructed correctly
# # Write-Output "Condition: $condition"

# # Construct the query
# $query = @"
# Resources
# | where type =~ 'Microsoft.Network/routeTables'
# | where $condition
# | project id
# "@

# # Check if the query is constructed correctly
# # Write-Output "Query: $query"

# # Execute the query
# $results = Search-AzGraph -Query $query -First 1000

# $results.Count

# # Extract route table names
# $routeTableNames += $results

# $routeTableNames

# $routeTableNames.Count

# Combine hub and spoke subscription data
$combinedResults = $resultsarray | ForEach-Object {
  [pscustomobject]@{
      Subscription = $_.HubSubscription
      Vnet = $_.hubvNetobj
  }
  [pscustomobject]@{
      Subscription = $_.SpokeSubscription
      Vnet = $_.SpokehubvNetobj
  }
}

# Filter unique subscription and vNet pairs
$uniqueResults = $combinedResults | Sort-Object Subscription, Vnet -Unique

# Display results
$uniqueResults | Format-Table -AutoSize

$uniqueResultsGroupedBySub = $uniqueResults | Group-Object Subscription
# Format output to show grouped vNets per Subscription
$uniqueResultsGroupedBySub = $uniqueResultsGroupedBySub | ForEach-Object {
    [pscustomobject]@{
        Subscriptions = $_.Name
        Vnets = ($_.Group.Vnet | Select-Object -Unique) -join ", "
    }
}

# Display results
$uniqueResultsGroupedBySub | Format-Table -AutoSize

# # Check if subscription exists in grouped results
# if ($uniqueResultsGroupedBySub.Subscriptions -contains "DUAL-INFRA-PREPROD") {
#   # Retrieve corresponding vNets
#   $vnets = ($uniqueResultsGroupedBySub | Where-Object { $_.Subscriptions -eq "DUAL-INFRA-PREPROD" }).Group.Vnets
#   $vnets

#   # Build condition for query
#   $condition = ($vnets | ForEach-Object { "properties.subnets[0].id has '$_'" }) -join " or "
#   $condition

#   # Construct the query
#   $query = 
# @"
# Resources
# | where type =~ 'Microsoft.Network/routeTables'
# | where $condition
# | project id
# "@

#   # Execute query in Azure Resource Graph
#   $results = Search-AzGraph -Query $query -First 1000

#   # Output results
#   $results
# } else {
#   Write-Output "------------ Subscription DUAL-INFRA-PREPROD not found in grouped results."
# }

# Ensure subscription names are properly stored
$subscriptionNames = $uniqueResultsGroupedBySub | Select-Object -ExpandProperty Subscriptions

# Check if the subscription exists
if ($subscriptionNames -contains "DUAL-INFRA-DEVTEST") {
  # Retrieve corresponding vNets (split comma-separated string into array)
  $vnetsString = ($uniqueResultsGroupedBySub | Where-Object { $_.Subscriptions -eq "DUAL-INFRA-DEVTEST" }).Vnets
  $vnets = $vnetsString -split ", "

  # Display vNets
  Write-Output "Vnets for DUAL-INFRA-PREPROD: $vnets"

  # Build condition for Azure Resource Graph query
  $condition = ($vnets | ForEach-Object { "properties.subnets[0].id has '$_'" }) -join " or "

  # Display condition for debugging
  Write-Output "Query Condition: $condition"

  # Construct the query
  $query = @"
  Resources
  | where type =~ 'Microsoft.Network/routeTables'
  | where $condition
  | project id
"@

  "Query: $query"

  # Execute query in Azure Resource Graph
  $results = Search-AzGraph -Query $query -First 1000

  # Output results
  $results
  $results.Count

  $routeTableids += $results
  $routeTableids
  "Total Route Tables in Scope: $($routeTableids.Count)"            # $results.Count == $routeTableids.Count
  $routeTableids = $routeTableids | Select-Object -ExpandProperty id
  $routeTableids
} else {
  Write-Output "------------ Subscription DUAL-INFRA-DEVTEST not found in grouped results."
}
