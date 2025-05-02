
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
param (
  [Parameter(Mandatory=$true)]
  [string]$subscriptionName
)

try
{
  "Logging in to Azure..."
  Connect-AzAccount -Identity
}
catch {
  Write-Error -Message $_.Exception
  throw $_.Exception
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------


#-----------------------------------------------------------[Execution]------------------------------------------------------------

##  SECTION I - GET ALL SUBSCRIPTIONS AND VNETS IN SCOPE
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

    $object = [pscustomobject]@{
      HubSubscription = $HubSubscription.name.split(" ")[0]
      hubvNetobj = $hubvNetobj.Name
      SpokeSubscription = $SpokeSubscription.name.split(" ")[0]
      SpokehubvNetobj = $RemotevNetobj.Name
    }
    $resultsarray += $object
  }
}

# $resultsarray 

# Collect unique subscriptions and VNets
$uniqueSubscriptions = $resultsarray | ForEach-Object {
  $_.HubSubscription
  $_.SpokeSubscription
} | Sort-Object -Unique

$uniqueVNets = $resultsarray | ForEach-Object {
  $_.hubvNetobj
  $_.SpokehubvNetobj
} | Sort-Object -Unique

"Unique Subscriptions Count: $($uniqueSubscriptions.Count)"
"Unique vNets Count: $($uniqueVNets.Count)"

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


##  SECTION II - FIND ROUTE TABLES IN SCOPE
# Ensure subscription names are properly stored
$subscriptionNames = $uniqueResultsGroupedBySub | Select-Object -ExpandProperty Subscriptions

# Check if the subscription exists
if ($subscriptionNames -contains $subscriptionName) {
  # Retrieve corresponding vNets (split comma-separated string into array)
  $vnetsString = ($uniqueResultsGroupedBySub | Where-Object { $_.Subscriptions -eq $subscriptionName }).Vnets
  $vnets = $vnetsString -split ", "

  # Display vNets
  Write-Output "Vnets for $subscriptionName subscription: $vnets"

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

  # Get SQL credentials and prepare report array
  $sqlcreds = Get-AutomationPSCredential -Name 'sql-prod-it-automation-ne01.database.windows.net'
  $RT_Report = @()

  ##  SECTION III - VALIDATE ROUTE TABLES
  Select-AzSubscription -SubscriptionId $subscriptionName
  foreach ($routeTableid in $routeTableids) {
    $RouteTableObj = Get-AzRouteTable -Name $routeTableid.split("/")[-1]

    if (($RouteTableObj.Name -notlike "*-PALO-*") -and ($RouteTableObj.Name -notlike "RT-PROD-GW-*")) {
      Write-Output "Validating route table $($RouteTableObj.Name) ..."
      switch -Wildcard ($RouteTableObj.location) {
        "NorthEurope" {
          $Hub = "EU-HUB"
          $GatewayIP = "10.6.241.10"
        }
        "WestEurope" {
          $Hub = "EU-HUB"
          $GatewayIP = "10.11.241.10"
        }
        "UKSouth" {
          $Hub = "EU-HUB"
          $GatewayIP = "10.12.241.10"
        }
        "EastAsia" {
          $Hub = "ASIA-HUB"
          $GatewayIP = "10.65.14.75"
        }
        "SouthEastAsia" {
          $Hub = "ASIA-HUB"
          $GatewayIP = "10.64.14.75"
        }
        "AustraliaEast" {
          $Hub = "AUS-HUB"
          $GatewayIP = "10.66.14.75"
        }
        "CentralUS" {
          $Hub = "US-HUB"
          $GatewayIP = "10.84.14.75"
        }
        "EastUS2" {
          $Hub = "US-HUB"
          $GatewayIP = "10.85.14.75"
        }
      }

      $dbRoutes = Invoke-Sqlcmd -Query "SELECT * From dbo.Routes WHERE (hubname like '$Hub'); " -ServerInstance "sql-prod-it-automation-ne01.database.windows.net" -Credential $sqlcreds -Database "DB-PROD-OPS-AUTOMATION-NE01" -QueryTimeout 20
          
      $hubVNets = @("VNET1-EU-North", "VNET1-EU-West", "VNET-PROD-UKS01", "VNET-HSL-INFRA-PROD-SA01", "VNET-HSL-INFRA-PROD-EA01", "VNET-HGS-INFRA-PROD-AE01", "VNET-HGS-INFRA-PROD-UC01", "VNET-HGS-INFRA-PROD-UE01")

      # Get the vNet in which the RT exists
      # $vNet = (Get-AzVirtualNetwork | Where-Object { $_.Subnets.Name -eq ($routeTable.Name -replace "^RT-", "") }).Name

      # $vNet = ((Get-AzRouteTable -Name $routeTable).SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 8
      $vNet = ($RouteTableObj.SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 8

      $currentRoutes = $RouteTableObj.Routes
      $missingRoutes = @()

      foreach ($dbRoute in $dbRoutes) {
        if (($dbRoute.Region -eq 'all') -or ($dbRoute.Region -eq $RouteTableObj.Location)) {
          if (($dbRoute.Name -like "PA-P-FW-*") -and ($hubVNets -contains $vNet)) {               #Hub vNet FW trust routes
            $match = $currentRoutes | Where-Object {
              $_.Name -eq $dbRoute.Name -and
              $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
              $_.NextHopType -eq $dbRoute.NextHopType -and
              $_.NextHopIpAddress -eq $null
            }
          }
          if (($dbRoute.Name -like "PA-P-FW-*") -and ($hubVNets -notcontains $vNet)) {            #Spoke vNet FW trust routes
            $match = $currentRoutes | Where-Object {
              $_.Name -eq $dbRoute.Name -and
              $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
              $_.NextHopType -eq "VirtualAppliance" -and
              $_.NextHopIpAddress -eq ($dbroute.AddressPrefix -replace "/\d+$", "")
            }
          }
          if ($dbRoute.Name -like "*-PALO-MAN-*") {
            $match = $currentRoutes | Where-Object {
              $_.Name -eq $dbRoute.Name -and
              $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
              $_.NextHopType -eq $dbRoute.NextHopType #-and
              # $_.NextHopIpAddress -eq $null
            }
          }
          if ($dbRoute.Name -like "*-PALO-CLIENT-VPN-POOL-*") {
            $match = $currentRoutes | Where-Object {
              $_.Name -eq $dbRoute.Name -and
              $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
              $_.NextHopType -eq $dbRoute.NextHopType -and
              $_.NextHopIpAddress -eq $dbRoute.NetxtHopIP
            }
          }
          if (($dbRoute.Name -notlike "PA-P-FW-*") -and ($dbRoute.Name -notlike "*-PALO-MAN-*") -and ($dbRoute.Name -notlike "*-PALO-CLIENT-VPN-POOL-*")) {                                               #All other routes
            $match = $currentRoutes | Where-Object {
              ($_.Name -eq $dbRoute.Name -or
              $_.AddressPrefix -eq $dbRoute.AddressPrefix) -and
              $_.NextHopType -eq $dbRoute.NextHopType -and
              $_.NextHopIpAddress -eq $GatewayIP
            }
          }
        
          if (-not $match) {
            $missingRoutes += $dbRoute.Name
          }
        }
      }

      if ($missingRoutes) {
        Write-Output "Missing/Incorrect routes found"
        $RT_Report += [PSCustomObject]@{
          SubscriptionName = $subscriptionName
          ResourceGroupName = $RouteTableObj.ResourceGroupName
          RouteTableName = $RouteTableObj.Name
          Location = $RouteTableObj.Location
          MissingOrIncorrectRoutes = $missingRoutes -join ", "
        }
      } 
      else { 
        Write-Output "No missing/incorrect routes in $($RouteTableObj.Name)" 
      }
    }
  }

  ## SECTION IV - GENERATE CSV AND SEND EMAIL

  $date = Get-Date -format "dd/MM/yyyy"
  Write-Output "Route Table Compliance Report:" 
  $RT_Report | Format-Table -AutoSize
  Write-Output "RT_Report Count: $($RT_Report.Count)"

  # Convert report to CSV
  $csvFilePath = ".\RouteTableComplianceReport.csv"
  $RT_Report | Export-Csv -Path $csvFilePath -NoTypeInformation
  $file_bytes = [System.IO.File]::ReadAllBytes($csvFilePath)

  $subject = "Route Table Compliance Report - $date - $subscriptionName"
  $emailFrom = "AzureAutomation@service.howdengrp.com"
  $emailTo = "shoaib.mohiuddin@cloudreach.com"
  $toName = "CloudreachSupport"
  $endpoint = "https://autoacc-prod-it-ops-comm-service.europe.communication.azure.com/"

  $emailRecipientTo = @(
    @{
      Address = $emailTo
      DisplayName = $toName
    }
  )

  $emailAttachment = @(
    @{
      ContentInBase64 = $file_bytes
      ContentType = "text/csv"
      Name = "RouteTableComplianceReport-$date-$subscriptionName.csv"
    }
  )
  $message = @{
    ContentSubject = $subject
    RecipientTo = @($emailRecipientTo)
    SenderAddress = $emailFrom
    ContentHtml = "<html><body><p>Please find the attached Route Table Compliance Report.</p><p>Please refer to the document linked below to take appropriate action based on the report findings:</p><p><a href='https://cloudreach.jira.com/wiki/spaces/CO/pages/5408751617/Action+on+Compliance+Report+Not+live+yet'>Action on Compliance Report</a></p></body></html>"
    Attachment = @($emailAttachment)
  }

  try {
    $poller = Send-AzEmailServicedataEmail -Message $Message -endpoint $endpoint # It should be $Message and not $message as with latter it is failing
    $result = $poller.Result
    Write-Output "Email sent."
  } catch {
    Write-Error "Error sending email: $_"
  }
} 
else {
  Write-Output "Subscription $subscriptionName is not in scope."
}



