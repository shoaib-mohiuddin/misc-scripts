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

function Add-LocalRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj)
    Write-Output "Adding local routes to Route Table: $($RouteTableObj.Name) (placeholder)."

    if ($LocalSubnetAddressPrefix){
        Add-AzRouteConfig -Name "LocalSubnet" -AddressPrefix $LocalSubnetAddressPrefix -NextHopType "VnetLocal" -RouteTable  $RouteTableObj
    }
}

function Add-CustomRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj, [Parameter(Mandatory = $true)] $customRoutes)
    Write-Output "Adding custom routes to Route Table: $($RouteTableObj.Name) (placeholder)."

    foreach ($customRoute in $customRoutes) {
        Add-AzRouteConfig -Name $customRoute.Name -AddressPrefix $customRoute.AddressPrefix -NextHopType $customRoute.NextHopType -NextHopIpAddress $customRoute.NextHopIPAddress -RouteTable  $RouteTableObj
    }
}

function Delete-CustomRoutes {
    param ([Parameter(Mandatory = $true)] $routeTableName, [Parameter(Mandatory = $true)] $customRoutes)
    Write-Output "Deleting custom routes from Route Table: $($routeTableName) (placeholder)."

    foreach ($customRoute in $customRoutes) {
        Remove-AzRouteConfig -Name $customRoute.Name -RouteTable $routeTableName
    }
}

function Move-RouteTableToVNetResourceGroup {
    param (
        [Parameter(Mandatory = $true)] [string] $routeTableName,
        [Parameter(Mandatory = $true)] [string] $resourceGroup
    )
    Write-Output "Route Table $routeTableName moved to the correct VNet resource group (placeholder)."

    $destRGName = ((Get-AzRouteTable -Name "RT-SUB-HINT-INFRA-DEV-TEST-SINGULARSQL-NE01").SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 4
    $resources = Get-AzResource -ResourceGroupName $resourceGroup | Where-Object { $_.Name -eq $routeTableName }
    Move-AzResource -DestinationResourceGroupName $destRGName -ResourceId $resources.ResourceId
}

function Validate-RouteTables {
    $RG_Compliance = ""
    $RT_Compliance = ""
    $RT_Report = @()
    $subscriptions = Get-AzSubscription

    Set-AzContext -SubscriptionName "HGS-INFRA-PROD"

    foreach ($subscription in $subscriptions) {
        $Tags = $subscription.Tags
        if ($Tags["SubscriptionType"] -ne "DatacenterExtension") {
            Write-Output "Subscription $subscription is not tagged with SubscriptionType=DatacenterExtension. Exiting."
        } 
        else {
            Write-Output "Subscription $subscription is tagged with SubscriptionType=DatacenterExtension. Proceeding..."
            $routeTables = Get-AzRouteTable
            foreach ($routeTable in $routeTables) {
                if ($routeTable.ResourceGroupName -notlike "*-NETWORK-*") {
                    Write-Output "$routeTable is in Incorrect resource group"
                    $RG_Compliance = "Incorrect resource group"
                } 
                else {
                    Write-Output "$routeTable is in Correct resource group"
                    $RG_Compliance = "Correct resource group"
                }

                if (($routeTable.Name -notcontains "*-PALO-*") -and ($routeTable.Name -notcontains "RT-PROD-GW-*")) {
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

                    foreach ($dbRoute in $dbRoutes) {
                        if (($dbRoute.Region -eq 'all') -or ($dbRoute.Region -eq $routeTable.Location)) {
                            $match = $currentRoutes | Where-Object {
                                $_.Name -eq $dbRoute.Name -and
                                $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
                                $_.NextHopType -eq $dbRoute.NextHopType
                            }
                        
                            if (-not $match) {
                                $missingRoutes += $dbRoute
                            }
                        }
                    }

                    # foreach ($currentRoute in $currentRoutes) {
                    #     $match = $dbRoutes | Where-Object {
                    #         $_.Name -eq $currentRoute.Name -and
                    #         $_.AddressPrefix -eq $currentRoute.AddressPrefix -and
                    #         $_.NextHopType -eq $currentRoute.NextHopType
                    #     }
                    
                    #     if (-not $match) {
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
                        $RT_Compliance = "Route table non-compliant with DB"
                        $RT_Report += @{
                            ResourceGroupName = $routeTable.ResourceGroupName
                            RouteTableName = $routeTable.Name
                            RG_Compliance = $RG_Compliance
                            RT_Compliance = $RT_Compliance
                            MissingRoutes = $missingRoutes
                        }
                    }
                }
            }
        }
    }
}

$mode = funccullspaces($mode)
$routeTableName = funccullspaces($routeTableName)
$resourceGroup = funccullspaces($resourceGroup)
# $subscriptionName = funccullspaces($subscriptionName)

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
    Write-Output "Disabling locks on Resource Group: $resourceGroup"
    $Locks = Get-AzResourceLock -ResourceGroupName $resourceGroup 
    if ($Locks) {
        foreach ($Lock in $Locks) {
            Remove-AzResourceLock -LockId $Lock.LockId -Force
        }
        Write-Output "Resource group locks disabled."
    }

    # Retrieve the Route Table
    # $RouteTableObj = Get-AzRouteTable -ResourceGroupName $ResourceGroup -Name $routeTableName

    # Handle operations based on the selected mode
    switch ($mode) {
        "create" {
            if ($resourceGroup -notlike "*-NETWORK-*") {
                Write-Error "Resource group name does not contain '*-NETWORK-*'. Operation not permitted."
                break
            } else {
                Write-Output "Creating new Route Table: $routeTableName in Resource Group: $resourceGroup"
                $RouteTableObj = New-AzRouteTable -Name $routeTableName -ResourceGroupName $resourceGroup -Location (Get-AzResourceGroup -Name $resourceGroup).Location 
                Write-Output "Route Table created successfully."

                Add-StandardRoutes -RouteTable $RouteTableObj
                Add-LocalRoutes -RouteTable $RouteTableObj

                if ($customRoutes) {
                    Add-CustomRoutes -RouteTable $RouteTableObj -CustomRoutes $customRoutes
                }
            } 
            # else {
            #     Write-Error "Route Table $routeTableName already exists."
            # }
        }

        "addRoutes" {
            if ($routeTableName) {
                if ($customRoutes) {
                    Write-Output "Adding custom routes to Route Table: $routeTableName"
                    Add-CustomRoutes -RouteTable $routeTableName -CustomRoutes $customRoutes
                } else {
                    Write-Error "No custom routes provided for 'addRoutes' mode."
                }
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "deleteRoutes" {
            if ($routeTableName) {
                if ($customRoutes) {
                    Write-Output "Deleting custom routes from Route Table: $routeTableName"
                    Delete-CustomRoutes -RouteTable $routeTableName -CustomRoutes $customRoutes
                } else {
                    Write-Error "No custom routes provided for 'deleteRoutes' mode."
                }
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "delete" {
            if ($routeTableName) {
                Write-Output "Deleting Route Table: $routeTableName"
                Remove-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName -Force
                Write-Output "Route Table deleted successfully."
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "update" {
            if ($resourceGroup -notcontains "*-NETWORK-*") {
                Write-Output "Moving the Route Table $routeTableName to the correct resource group for the associated VNet..."
                # Logic to move the Route Table to the correct resource group
                Move-RouteTableToVNetResourceGroup -RouteTableName $routeTableName -ResourceGroupName $resourceGroup
            }

            if ($routeTableName) {
                Write-Output "Updating Route Table: $routeTableName"
                Add-StandardRoutes -RouteTable $routeTableName
                # Add-LocalRoutes -RouteTable $routeTableName
                Write-Output "Route Table updated successfully."
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "validate" {
            Validate-RouteTables 
        }
    }

    # Enable Resource Group Lock
    Write-Output "Enabling locks on Resource Group: $resourceGroup"
    if ($Locks) {
        foreach ($Lock in $Locks) {
            New-AzResourceLock -LockName $Lock.Name -LockLevel $Lock.Properties.level -ResourceGroupName $resourceGroup -Force
        }
        Write-Output "Resource group locks re-enabled."
    }
}

if ($RT_Report.Count -gt 0) {
    $RT_Report = $RT_Report | Out-String

    #PagerDuty
    $pagerDutyApiUrl = "https://events.pagerduty.com/v2/enqueue"
    $pagerDutyRoutingKey = ""  # Add key here

    $pagerDutyPayload = @{
        routing_key = $pagerDutyRoutingKey
        event_action = "trigger"
        payload = @{
            summary = "Route Table misconfigurations detected for Subscription $subscription"
            severity = "info"  # Adjust based on severity (info, warning, error, critical)
            source = "Azure Automation Account"
            # component = "Azure Route Tables"
            custom_details = @{
                Report = $RT_Report  # Include report as part of the payload
            }
        }
    }

    # Convert the payload to JSON and send it to PagerDuty API
    $pagerDutyResponse = Invoke-RestMethod -Uri $pagerDutyApiUrl -Method Post -Body ($pagerDutyPayload | ConvertTo-Json -Depth 3) -ContentType "application/json"

    # Check if the PagerDuty alert was triggered successfully
    if ($pagerDutyResponse.status -eq "success") {
        "PagerDuty alert triggered."
    } else {
        "Failed to trigger PagerDuty alert."
    }
}
# else {
#     "No Route Table misconfigurations were found"
# }