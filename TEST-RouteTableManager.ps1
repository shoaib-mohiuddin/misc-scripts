param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "update", "addRoutes", "deleteRoutes", "delete", "validate")]
    [string]$mode,

    [Parameter(Mandatory=$true)]
    [string]$subscriptionName,

    [Parameter(Mandatory=$true)]
    [string]$resourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$routeTableName,

    [Parameter(Mandatory=$false)]
    [array]$customRoutes,

    [Parameter(Mandatory=$false)]
    [string]$LocalSubnetAddressPrefix
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

function funccullspaces($param) {
    $param = $param.trim()
    $param = $param.replace(' ', '')
    return $param
}
################################################################################
# Function placeholders for adding routes and moving route tables

function Add-StandardRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj)
    Write-Output "Adding standard routes to Route Table: $($RouteTableObj.Name)."

    if (($RouteTableObj.Name -notcontains "*-PALO-*") -and ($RouteTableObj.Name -notcontains "RT-PROD-GW-*")){
    
        $RTResourceObj = Get-AzRouteTable -Name $routeTableName
        $RouteTableObJ = Get-AzRouteTable -ResourceGroupName $RTResourceObj.ResourceGroupName -Name $RTResourceObj.Name
    
        switch -Wildcard ($RouteTableObJ.location) {
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
    
        #if ($routedbreturn.HubName[0] -ne $hub) {
        $routedbreturn = Invoke-Sqlcmd -Query "SELECT * From dbo.Routes WHERE (hubname like '$Hub'); " -ServerInstance "sql-prod-it-automation-ne01.database.windows.net" -Credential $sqlcreds -Database "DB-PROD-OPS-AUTOMATION-NE01" -QueryTimeout 20
        #}
      
        Foreach ($dbroute in $routedbreturn) {
            if ($RouteTableObJ.Routes.AddressPrefix -notcontains $dbroute.AddressPrefix) {
                if (($dbroute.Region -eq 'all') -or ($dbroute.Region -eq $RouteTableObJ.Location)) {
    
                  #  $dbroute.Name
                  #  $RTResourceObj.Location
                    if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -eq 'regionspecific' )) {
                        Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $GatewayIP -RouteTable $RouteTableObJ
                    }            
                    if (($dbroute.NextHopType -eq "VnetLocal") -and ($dbroute.NetxtHopIP -eq 'notapplicable' )) {
                        Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -RouteTable $RouteTableObJ
                    }
                    if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -ne 'regionspecific' )) {
                        Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $dbroute.NetxtHopIP -RouteTable  $RouteTableObJ
                    }
                    Set-AzRouteTable -RouteTable $RouteTableObJ
                }
            }
        }
    }
}

# To avoid route overwrite,
# 1. Retrieve the latest route table object from Azure at the beginning of every function using Get-AzRouteTable.
# 2. Modify the route table in-memory using Add-AzRouteConfig.
# 3. Commit the changes to Azure using Set-AzRouteTable immediately after every function's updates.

function Add-LocalRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj)
    Write-Output "Adding local routes to Route Table: $($RouteTableObj.Name)"

    $RouteTableObj = Get-AzRouteTable -Name $routeTableName
    Add-AzRouteConfig -Name "LocalSubnet" -AddressPrefix $LocalSubnetAddressPrefix -NextHopType "VnetLocal" -RouteTable  $RouteTableObj
    Set-AzRouteTable -RouteTable $RouteTableObj
}

function Add-CustomRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj, [Parameter(Mandatory = $true)] $customRoutes)
    Write-Output "Adding custom routes to Route Table: $($RouteTableObj.Name)"

    $RouteTableObj = Get-AzRouteTable -Name $routeTableName
    foreach ($customRoute in $customRoutes) {
        Add-AzRouteConfig -Name $customRoute.routeName -AddressPrefix $customRoute.addressPrefix -NextHopType $customRoute.nextHopType -NextHopIpAddress $customRoute.nextHopIpAddress -RouteTable  $RouteTableObj
    }
    Set-AzRouteTable -RouteTable $RouteTableObj
}

function Delete-CustomRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj, [Parameter(Mandatory = $true)] $customRoutes)
    Write-Output "Deleting custom routes from Route Table: $($routeTableName)"

    $RouteTableObj = Get-AzRouteTable -Name $routeTableName
    foreach ($customRoute in $customRoutes) {
        Remove-AzRouteConfig -Name $customRoute.routeName -RouteTable $RouteTableObj
    }
    Set-AzRouteTable -RouteTable $RouteTableObj
}

# function Move-RouteTableToVNetResourceGroup {
#     param (
#         [Parameter(Mandatory = $true)] [string] $routeTableName,
#         [Parameter(Mandatory = $true)] [string] $resourceGroup
#     )
#     Write-Output "Route Table $routeTableName moved to the correct VNet resource group."

#     $destRGName = ((Get-AzRouteTable -Name "RT-SUB-HINT-INFRA-DEV-TEST-SINGULARSQL-NE01").SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 4
#     $resources = Get-AzResource -ResourceGroupName $resourceGroup | Where-Object { $_.Name -eq $routeTableName }
#     Move-AzResource -DestinationResourceGroupName $destRGName -ResourceId $resources.ResourceId
# }

function Validate-RouteTables {
    param ( [Parameter(Mandatory = $true)] [ref] $RT_Report )
    $RG_Compliance = ""
    $RT_Compliance = ""
    # $RT_Report = @()
    $subscriptions = Get-AzSubscription

    foreach ($subscription in $subscriptions) {
        Set-AzContext -SubscriptionId $subscription.Id
        $Tags = $subscription.Tags
        if ($Tags["SubscriptionType"] -ne "DatacenterExtension") {
            Write-Output "Subscription $($subscription.Name) is not tagged with SubscriptionType=DatacenterExtension. Exiting."
        } 
        else {
            Write-Output "Subscription $($subscription.Name) is tagged with SubscriptionType=DatacenterExtension. Proceeding..."
            $routeTables = Get-AzRouteTable
            foreach ($routeTable in $routeTables) {
                if ($routeTable.ResourceGroupName -notlike "*-NETWORK-*") {
                    Write-Output "$($routeTable.Name) is in Incorrect resource group $($routeTable.ResourceGroupName)"
                    $RG_Compliance = "Incorrect resource group"
                } 
                else {
                    Write-Output "$($routeTable.Name) is in Correct resource group $($routeTable.ResourceGroupName)"
                    $RG_Compliance = "Correct resource group"
                }

                if (($routeTable.Name -notcontains "*-PALO-*") -and ($routeTable.Name -notcontains "RT-PROD-GW-*")) {
                    Write-Output "Validating route table $($routeTable.Name)..."
                    switch -Wildcard ($routeTable.location) {
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

                    $currentRoutes = $routeTable.Routes
                    # Compare routes
                    $missingRoutes = @()
                    # $extraRoutes = @()

                    Write-Output "Checking for missing routes..."
                    foreach ($dbRoute in $dbRoutes) {
                        if (($dbRoute.Region -eq 'all') -or ($dbRoute.Region -eq $routeTable.Location)) {
                            $match = $currentRoutes | Where-Object {
                                $_.Name -eq $dbRoute.Name -and
                                $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
                                $_.NextHopType -eq $dbRoute.NextHopType
                            }
                        
                            if (-not $match) {
                                Write-Output "Missing route found: $($dbRoute.Name)"
                                $missingRoutes += $dbRoute
                            }
                        }
                    }

                    # Write-Output "Checking for extra routes..."
                    # foreach ($currentRoute in $currentRoutes) {
                    #     $match = $dbRoutes | Where-Object {
                    #         $_.Name -eq $currentRoute.Name -and
                    #         $_.AddressPrefix -eq $currentRoute.AddressPrefix -and
                    #         $_.NextHopType -eq $currentRoute.NextHopType
                    #     }
                    
                    #     if (-not $match) {
                    #         Write-Output "Extra route found: $($currentRoute.Name)"
                    #         $extraRoutes += $currentRoute
                    #     }
                    # }
                    
                    # Log misconfigurations
                    # if ($missingRoutes) {
                    #     Write-Output "Missing routes in route table:"
                    #     $missingRoutes | Format-Table
                    # }
                    
                    # if ($extraRoutes) {
                    #     Write-Output "Extra routes in route table:"
                    #     $extraRoutes | Format-Table
                    # }

                    if ($missingRoutes) {
                        Write-Output "Missing routes in $($routeTable.Name):"
                        $missingRoutes | Format-Table
                        # $extraRoutes | Format-Table
                        $RT_Compliance = "Route table non-compliant with DB"
                        $RT_Report += [PSCustomObject]@{
                            SubscriptionName = $subscription.Name
                            ResourceGroupName = $routeTable.ResourceGroupName
                            RouteTableName = $routeTable.Name
                            RG_Compliance = $RG_Compliance
                            RT_Compliance = $RT_Compliance
                            MissingRoutes = $missingRoutes
                            # ExtraRoutes = $extraRoutes
                        }
                    } else { 
                        Write-Output "No missing routes in $($routeTable.Name)" 
                    }
                }
            }
        }
    }
    # Write-Output "Route Table Compliance Report:" 
    # $RT_Report | Format-Table
}

$mode = funccullspaces($mode)
$routeTableName = funccullspaces($routeTableName)
$resourceGroup = funccullspaces($resourceGroup)
$subscriptionName = funccullspaces($subscriptionName)

$sqlcreds = Get-AutomationPSCredential -Name 'sql-prod-it-automation-ne01.database.windows.net'

Select-AzSubscription -SubscriptionName $subscriptionName
# Write-Output "Selected Subscription: $subscriptionName"

# Retrieve subscription tags
$Subscription = Get-AzSubscription -SubscriptionName $subscriptionName
$Tags = $Subscription.Tags

if ($Tags["SubscriptionType"] -ne "DatacenterExtension") {
    Write-Output "Subscription $subscriptionName is not tagged with SubscriptionType=DatacenterExtension. Exiting."
    return
} 
else {

    Write-Output "Subscription $subscriptionName is tagged with SubscriptionType=DatacenterExtension. Proceeding..."

    # Disable Resource Group Lock
    # $Locks = Get-AzResourceLock -ResourceGroupName $resourceGroup 
    # if ($Locks) {
    #     Write-Output "Disabling locks on Resource Group: $resourceGroup"
    #     foreach ($Lock in $Locks) {
    #         Remove-AzResourceLock -LockId $Lock.LockId -Force
    #     }
    #     Write-Output "Resource group locks disabled."
    # }

    # Retrieve the Route Table
    # $RouteTableObj = Get-AzRouteTable -ResourceGroupName $ResourceGroup -Name $routeTableName

    # Handle operations based on the selected mode
    switch ($mode) {
        "create" {
            if ($resourceGroup -notlike "*-NETWORK-*") {
                Write-Error "Resource group name does not contain '*-NETWORK-*'. Operation not permitted."
                break
            } 
            else {
                Write-Output "Creating new Route Table: $routeTableName in Resource Group: $resourceGroup"
                $RouteTableObj = New-AzRouteTable -Name $routeTableName -ResourceGroupName $resourceGroup -Location (Get-AzResourceGroup -Name $resourceGroup).Location 
                Write-Output "Route Table created successfully."

                Add-StandardRoutes -RouteTable $RouteTableObj

                if ($LocalSubnetAddressPrefix) {
                    Add-LocalRoutes -RouteTable $RouteTableObj
                }

                if ($customRoutes) {
                    Add-CustomRoutes -RouteTable $RouteTableObj -CustomRoutes $customRoutes
                }
            } 
        }

        "addRoutes" {
            $RouteTableObj = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName
            if ($RouteTableObj) {
                if ($customRoutes) {
                    Add-CustomRoutes -RouteTable $RouteTableObj -CustomRoutes $customRoutes
                } else {
                    Write-Error "No custom routes provided for 'addRoutes' mode."
                }
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "deleteRoutes" {
            $RouteTableObj = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName
            if ($RouteTableObj) {
                if ($customRoutes) {
                    Delete-CustomRoutes -RouteTable $RouteTableObj -CustomRoutes $customRoutes
                } else {
                    Write-Error "No custom routes provided for 'deleteRoutes' mode."
                }
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "delete" {
            $RouteTableObj = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName
            if ($RouteTableObj) {
                Write-Output "Deleting Route Table: $routeTableName"
                Remove-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName -Force
                Write-Output "Route Table deleted successfully."
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "update" {
            # if ($resourceGroup -notlike "*-NETWORK-*") {
            #     Write-Output "Moving the Route Table $routeTableName to the correct resource group for the associated VNet..."
            #     # Logic to move the Route Table to the correct resource group
            #     Move-RouteTableToVNetResourceGroup -RouteTableName $routeTableName -ResourceGroupName $resourceGroup
            # }

            $RouteTableObj = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName

            if ($RouteTableObj) {
                Write-Output "Updating Route Table: $routeTableName"
                Add-StandardRoutes -RouteTable $RouteTableObj
                # Add-LocalRoutes -RouteTable $routeTableName
                Write-Output "Route Table updated successfully."
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "validate" {
            $RT_Report = @()
            Validate-RouteTables -RT_Report ([ref]$RT_Report)
        }
    }

    # Enable Resource Group Lock
    # if ($Locks) {
    #     Write-Output "Enabling locks on Resource Group: $resourceGroup"
    #     foreach ($Lock in $Locks) {
    #         New-AzResourceLock -LockName $Lock.Name -LockLevel $Lock.Properties.level -ResourceGroupName $resourceGroup -Force
    #     }
    #     Write-Output "Resource group locks re-enabled."
    # }
}

Write-Output "RT_Report Count: $($RT_Report.Count)"
if ($RT_Report.Count -gt 0) {
    # $reportTable = $RT_Report | Format-Table -AutoSize | Out-String
    $reportMarkdown = @"
| SubscriptionName | ResourceGroupName | RouteTableName | RG_Compliance | MissingRoutes | |-------------------|------------------------------------|----------------------------------|-----------------------|------------------------------| $(foreach ($item in $RT_Report) { "| $($item.SubscriptionName) | $($item.ResourceGroupName) | $($item.RouteTableName) | $($item.RG_Compliance) | $($item.MissingRoutes) |" }) 
"@ 
    

    #PagerDuty
    Write-Output "Preparing to send PagerDuty alert..."
    $pagerDutyApiUrl = "https://events.pagerduty.com/v2/enqueue"
    $pagerDutyRoutingKey = "a028a804e290450cd037d428891aacba"  # Add key here

    $pagerDutyPayload = @{
        routing_key = $pagerDutyRoutingKey
        event_action = "trigger"
        payload = @{
            summary = "[TEST] Route Table misconfigurations detected"
            severity = "info"  # Adjust based on severity (info, warning, error, critical)
            source = "Azure Automation Account"
            custom_details = $reportTable
            # custom_details = @{
            #     Report = $reportTable  # Include report as part of the payload
            # }
        }
    }

    try {
        # Convert the payload to JSON and send it to PagerDuty API
        $pagerDutyResponse = Invoke-RestMethod -Uri $pagerDutyApiUrl -Method Post -Body ($pagerDutyPayload | ConvertTo-Json -Depth 3) -ContentType "application/json"

        # Check if the PagerDuty alert was triggered successfully
        if ($pagerDutyResponse.status -eq "success") {
            Write-Output "PagerDuty alert triggered."
        } else {
            Write-Output "Failed to trigger PagerDuty alert."
        }
    } catch {
        Write-Output "Error triggering PagerDuty alert: $_"
    }
} 
# else {
#     Write-Output "No Route Table misconfigurations were found"
# }
