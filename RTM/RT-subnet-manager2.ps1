## Creates subnet and RT - ruled out because of out of scope and the automation was becoming complicated for simple tasks. 
## For e.g, if the subnet is already present, the automation fails on subnet creation and continues with RT creation. 
## This can be handled in code logic, but like said before, the automation would become complex.


#---------------------------------------------------------[Initialisations]--------------------------------------------------------
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "update", "addRoutes", "deleteRoutes", "delete")]
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
    [string]$vNetname,
    
    [Parameter(Mandatory=$false)]
    [string]$subnetAddressPrefix
    
)

# Validate parameters based on mode
if ($mode -eq "create" -and ([string]::IsNullOrEmpty($vNetname) -or [string]::IsNullOrEmpty($subnetAddressPrefix))) {
    Write-Error "When mode is 'create', the parameters vNetname, and subnetAddressPrefix are required."
    return
}

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

function funccullspaces($param) {
    $param = $param.trim()
    $param = $param.replace(' ', '')
    return $param
}

function Add-StandardRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj)
    Write-Output "Adding standard routes to Route Table: $($RouteTableObj.Name)."

    if (($RouteTableObj.Name -notlike "*-PALO-*") -and ($RouteTableObj.Name -notlike "RT-PROD-GW-*")){
    
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
    
        $routedbreturn = Invoke-Sqlcmd -Query "SELECT * From dbo.Routes WHERE (hubname like '$Hub'); " -ServerInstance "sql-prod-it-automation-ne01.database.windows.net" -Credential $sqlcreds -Database "DB-PROD-OPS-AUTOMATION-NE01" -QueryTimeout 20

        $hubVNets = @("VNET1-EU-North", "VNET1-EU-West", "VNET-PROD-UKS01", "VNET-HSL-INFRA-PROD-SA01", "VNET-HSL-INFRA-PROD-EA01", "VNET-HGS-INFRA-PROD-AE01", "VNET-HGS-INFRA-PROD-UC01", "VNET-HGS-INFRA-PROD-UE01")
        
        # Get the vNet in which the RT exists
        # $vNet = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroup | Where-Object { $_.Subnets.Name -eq ($routeTableName -replace "^RT-", "") }).Name
        $vNet = ($RouteTableObJ.SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 8
    
        foreach ($dbroute in $routedbreturn) {
            if ($RouteTableObJ.Routes.AddressPrefix -notcontains $dbroute.AddressPrefix) {
                if (($dbroute.Region -eq 'all') -or ($dbroute.Region -eq $RouteTableObJ.Location)) {

                    if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -eq 'regionspecific' )) {
                        Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $GatewayIP -RouteTable $RouteTableObJ
                    }            
                    if (($dbroute.NextHopType -eq "VnetLocal") -and ($dbroute.NetxtHopIP -eq 'notapplicable' ) -and ($dbRoute.Name -like "PA-P-FW-*")) {
                        if ($hubVNets -contains $vNet) {
                            Write-Output "The VNet '$vNet' is a Hub VNet."
                            Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -RouteTable $RouteTableObJ
                        } else {
                            Write-Output "The VNet '$vNet' is a Spoke VNet."
                            Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType "VirtualAppliance" -NextHopIpAddress ($dbroute.AddressPrefix -replace "/\d+$", "") -RouteTable $RouteTableObJ
                        }
                    }
                    if (($dbroute.NextHopType -eq "VnetLocal") -and ($dbroute.NetxtHopIP -eq 'notapplicable' ) -and ($dbRoute.Name -like "*-PALO-MAN-*")) {
                        Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -RouteTable  $RouteTableObJ
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

function Add-CustomRoutes {
    param ([Parameter(Mandatory = $true)] $RouteTableObj, [Parameter(Mandatory = $true)] $customRoutes)
    Write-Output "Adding custom routes to Route Table: $($RouteTableObj.Name)"

    $RouteTableObj = Get-AzRouteTable -Name $routeTableName
    foreach ($customRoute in $customRoutes) {
    	if ($RouteTableObj.Routes.Name -contains $customRoute.routeName) {
    		Set-AzRouteConfig -Name $customRoute.routeName -AddressPrefix $customRoute.addressPrefix -NextHopType $customRoute.nextHopType -NextHopIpAddress $customRoute.nextHopIpAddress -RouteTable  $RouteTableObj
    	} 
    	else {

    		Add-AzRouteConfig -Name $customRoute.routeName -AddressPrefix $customRoute.addressPrefix -NextHopType $customRoute.nextHopType -NextHopIpAddress $customRoute.nextHopIpAddress -RouteTable  $RouteTableObj
    	}
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

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$mode = funccullspaces($mode)
$routeTableName = funccullspaces($routeTableName)
$resourceGroup = funccullspaces($resourceGroup)
$subscriptionName = funccullspaces($subscriptionName)

$sqlcreds = Get-AutomationPSCredential -Name 'sql-prod-it-automation-ne01.database.windows.net'

Select-AzSubscription -SubscriptionName $subscriptionName

$Subscription = Get-AzSubscription -SubscriptionName $subscriptionName
$Tags = $Subscription.Tags

if ($Tags["SubscriptionType"] -ne "DatacenterExtension") {
    Write-Error "Subscription $subscriptionName is not tagged with SubscriptionType=DatacenterExtension. Exiting."
    return
} 
else {

    Write-Output "Subscription $subscriptionName is tagged with SubscriptionType=DatacenterExtension. Proceeding..."

    # Handle operations based on the selected mode
    switch ($mode) {
        "create" {
            if ($resourceGroup -notlike "*-NETWORK-*") {
                Write-Error "Resource group name does not contain '*-NETWORK-*'. Operation not permitted."
                break
            } 
            else {
                # Write-Output "Creating new Subnet: $($routeTableName -replace '^RT-', '') & Route Table: $routeTableName in Resource Group: $resourceGroup"
                $Route = New-AzRouteConfig -Name "LocalSubnet" -AddressPrefix $subnetAddressPrefix -NextHopType "VnetLocal"
                $RouteTableObj = New-AzRouteTable -Name $routeTableName -ResourceGroupName $resourceGroup -Location (Get-AzResourceGroup -Name $resourceGroup).Location -Route $Route
                $Vnet= Get-AzVirtualNetwork -Name $vNetname
                $Subnet= Add-AzVirtualNetworkSubnetConfig -Name ($routeTableName -replace "^RT-", "") -VirtualNetwork $Vnet -AddressPrefix $subnetAddressPrefix -RouteTable $RouteTableObj
                $Vnet | Set-AzVirtualNetwork
                Write-Output "Subnet & Route Table created successfully."

                Add-StandardRoutes -RouteTable $RouteTableObj

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
                    Write-Error "No routes provided for 'addRoutes' mode."
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
                    Write-Error "No routes provided for 'deleteRoutes' mode."
                }
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "delete" {
            $RouteTableObj = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName
            if ($RouteTableObj) {
                Write-Output "Checking if the route table is associated with a subnet..."

                $vNet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup | Where-Object { $_.Subnets.Name -eq ($routeTableName -replace "^RT-", "") }
                $subnetObj = Get-AzVirtualNetworkSubnetConfig -Name ($routeTableName -replace "^RT-", "") -VirtualNetwork $vNet
                if ($subnetObj.RouteTable -ne $null -and $subnetObj.RouteTable.Id -eq $RouteTableObj.Id) {
                    $subnetObj.RouteTable = $null
                    $vNet | Set-AzVirtualNetwork
                    Write-Output "Route table de-associated from subnet."
                } else {
                    Write-Output "Route table is not associated with the subnet."
                }
                
                try {
                    Write-Output "Deleting Route Table: $routeTableName"
                    Remove-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName -Force
                    # Check if RT is deleted
                    $deletedRouteTable = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName -ErrorAction SilentlyContinue
                    if (-not $deletedRouteTable) {
                        Write-Output "Route Table deleted successfully."
                    }
                } catch {
                    Write-Error "Failed to delete route table: $_"
                }

            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }

        "update" {
            $RouteTableObj = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName

            if ($RouteTableObj) {
                Write-Output "Updating Route Table: $routeTableName"
                Add-StandardRoutes -RouteTable $RouteTableObj
                Write-Output "Route Table updated successfully."
            } else {
                Write-Error "Route Table $routeTableName does not exist."
            }
        }
    }
}
