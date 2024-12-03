param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "update", "addRoutes", "deleteRoutes", "delete")]
    [string]$mode,

    [Parameter(Mandatory=$true)]
    [string]$routeTableName,

    [Parameter(Mandatory=$true)]
    [string]$resourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$subscriptionName,

    [Parameter(Mandatory=$false)]
    [array]$customRoutes
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

$mode = funccullspaces($mode)
$routeTableName = funccullspaces($routeTableName)
$resourceGroup = funccullspaces($resourceGroup)
$subscriptionName = funccullspaces($subscriptionName)

$sqlcreds = Get-AutomationPSCredential -Name 'sql-autoacc-test.database.windows.net'

Select-AzSubscription -SubscriptionName $subscriptionName
Write-Output "Selected Subscription: $subscriptionName"

# Retrieve subscription tags
$Subscription = Get-AzSubscription -SubscriptionName $subscriptionName
$Tags = $Subscription.Tags

if ($Tags["SubscriptionType"] -ne "DatacenterExtension") {
    Write-Output "Subscription $subscriptionName is not tagged with SubscriptionType=DatacenterExtension. Exiting."
    return
}

Write-Output "Subscription $subscriptionName is valid with SubscriptionType=DatacenterExtension. Proceeding..."

# Disable Resource Group Lock
Write-Output "Disabling locks on Resource Group: $resourceGroup"
$Locks = Get-AzResourceLock -ResourceGroupName $resourceGroup 
if ($Locks) {
    foreach ($Lock in $Locks) {
        Remove-AzResourceLock -LockId $Lock.LockId
    }
    Write-Output "Resource group locks disabled."
}

# Retrieve the Route Table
# $RouteTableObj = Get-AzRouteTable -ResourceGroupName $ResourceGroup -Name $routeTableName

# Handle operations based on the selected mode
switch ($mode) {
    "create" {
        if ($resourceGroup -notcontains "*-NETWORK-*") {
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
}

# Enable Resource Group Lock
Write-Output "Enabling locks on Resource Group: $ResourceGroup"
if ($Locks) {
    foreach ($Lock in $Locks) {
        New-AzResourceLock -LockName $Lock.LockName -LockLevel $Lock.Level -ResourceGroupName $ResourceGroup
    }
    Write-Output "Resource group locks re-enabled."
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
        $routedbreturn = Invoke-Sqlcmd -Query "SELECT * From dbo.Routes WHERE (hubname like '$Hub'); " -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "DB-PROD-OPS-AUTOMATION-NE01" -QueryTimeout 20
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

    if ($subnetAddressPrefix){
        Add-AzRouteConfig -Name "LocalSubnet" -AddressPrefix $subnetAddressPrefix -NextHopType "VnetLocal" -RouteTable  $RouteTableObj
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
        [Parameter(Mandatory = $true)] [string] $routeTableName
        [Parameter(Mandatory = $true)] [string] $resourceGroup
    )
    Write-Output "Route Table $routeTableName moved to the correct VNet resource group (placeholder)."

    $destRGName = ((Get-AzRouteTable -Name "RT-SUB-HINT-INFRA-DEV-TEST-SINGULARSQL-NE01").SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 4
    $resources = Get-AzResource -ResourceGroupName $resourceGroup | Where-Object { $_.Name -in $routeTableName }
    Move-AzResource -DestinationResourceGroupName $destRGName -ResourceId $resources.ResourceId
}
