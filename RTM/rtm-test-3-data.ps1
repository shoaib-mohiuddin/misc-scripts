#---------------------------------------------------------[Initialisations]--------------------------------------------------------
param (
  [Parameter(Mandatory=$true)]
  [ValidateSet("create", "update", "addRoutes", "deleteRoutes", "delete")]
  [string]$mode,

  [Parameter(Mandatory=$true)]
  [string]$subscriptionName,

  [Parameter(Mandatory=$true)]
  [string]$resourceGroup, # must be same for all RTs

  # [Parameter(Mandatory=$true)]
  # [string[]]$routeTableNames, # expected format ["RT1Name","RT2Name"]
  [Parameter(Mandatory=$true)]
  [string]$routeTableName,

  [Parameter(Mandatory=$false)]
  [array]$customRoutes,

  [Parameter(Mandatory=$false)]
  [ValidateSet("GDLSpoke", "NoDefault", "OutOfScope")]
  [string]$TagRouteTableManager

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

function funccullspaces($param) {
  $param = $param.trim()
  $param = $param.replace(' ', '')
  return $param
}

function AddorUpdate-StandardRoutes {
  param ([Parameter(Mandatory = $true)] $RouteTableObj)
  Write-Output "Adding standard routes to Route Table: $($RouteTableObj.Name)."

  if (($RouteTableObj.Name -notlike "*-PALO-*") -and ($RouteTableObj.Name -notlike "RT-PROD-GW-*") -and ($RouteTableObj.Tag["RouteTableManager"] -ne "OutOfScope")) {

    $RouteTableObJ = Get-AzRouteTable -Name $RouteTableObj.Name

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
      if ($mode -in @("create", "update")) {
        if ($RouteTableObJ.Routes.AddressPrefix -notcontains $dbroute.AddressPrefix) {

          if ((($dbroute.Region -eq 'all') -or ($dbroute.Region -eq $RouteTableObJ.Location)) -and ($RouteTableObJ.Tag["RouteTableManager"] -ne "GDLSpoke")) {

            if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -eq 'regionspecific' ) -and ($dbRoute.Name -ne "default") -and ($dbRoute.Name -notlike "RFC*")) {
              Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $GatewayIP -RouteTable $RouteTableObJ
            } 
            if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -eq 'regionspecific' ) -and ($dbRoute.Name -eq "default") -and ($RouteTableObJ.Tag["RouteTableManager"] -ne "NoDefault")) {
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

          if ((($dbroute.Region -eq 'all') -or ($dbroute.Region -eq $RouteTableObJ.Location)) -and ($RouteTableObJ.Tag["RouteTableManager"] -eq "GDLSpoke")) {

            if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -eq 'regionspecific' ) -and ($dbRoute.Name -like "RFC*")) {             # like DATA-* or DATA-HUB-* or GDL-* or GDLSpoke-*
              Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $GatewayIP -RouteTable $RouteTableObJ
            }

            Set-AzRouteTable -RouteTable $RouteTableObJ
          }
        }
      }
      # if ($mode -eq "update") {
      #   if (($RouteTableObJ.Routes.AddressPrefix -contains $dbroute.AddressPrefix) -and ($RouteTableObJ.Routes.Name -contains $dbroute.Name)) {
      #     if (($dbroute.Region -eq 'all') -or ($dbroute.Region -eq $RouteTableObJ.Location)) {

      #       if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -eq 'regionspecific' )) {
      #         Set-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $GatewayIP -RouteTable $RouteTableObJ
      #       }            

      #       if (($dbroute.NextHopType -eq "VnetLocal") -and ($dbroute.NetxtHopIP -eq 'notapplicable' ) -and ($dbRoute.Name -like "*-PALO-MAN-*")) {
      #         Set-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -RouteTable  $RouteTableObJ
      #       }
      #       if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -ne 'regionspecific' )) {
      #         Set-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $dbroute.NetxtHopIP -RouteTable  $RouteTableObJ
      #       }

      #       Set-AzRouteTable -RouteTable $RouteTableObJ
      #     }
      #   }

      #   if (($dbRoute.Region -eq 'all') -or ($dbRoute.Region -eq $RouteTableObJ.Location)) {
      #     if (($dbroute.NextHopType -eq "VnetLocal") -and ($dbroute.NetxtHopIP -eq 'notapplicable' ) -and ($dbRoute.Name -like "PA-P-FW-*")) {
      #       if ($hubVNets -contains $vNet) {
      #         Write-Output "The VNet '$vNet' is a Hub VNet."
      #         Set-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -RouteTable $RouteTableObJ
      #       } else {
      #         Write-Output "The VNet '$vNet' is a Spoke VNet."
      #         Set-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType "VirtualAppliance" -NextHopIpAddress ($dbroute.AddressPrefix -replace "/\d+$", "") -RouteTable $RouteTableObJ
      #       }
      #     }
          
      #     Set-AzRouteTable -RouteTable $RouteTableObJ
      #   }
      # } 
    }
  }
}

function Add-LocalRoutes {
  param ([Parameter(Mandatory = $true)] $RouteTableObj)
  Write-Output "Adding local routes to Route Table: $($RouteTableObj.Name)"

  $RouteTableObj = Get-AzRouteTable -Name $RouteTableObj.Name
  $vNet = Get-AzVirtualNetwork -ResourceGroupName $RouteTableObj.ResourceGroupName | Where-Object { $_.Subnets.Name -eq ($RouteTableObj.Name -replace "^RT-", "") }
  $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNet -Name ($RouteTableObj.Name -replace "^RT-", "")
  Add-AzRouteConfig -Name "LocalSubnet" -AddressPrefix $subnet.AddressPrefix[0] -NextHopType "VnetLocal" -RouteTable  $RouteTableObj
  Set-AzRouteTable -RouteTable $RouteTableObj

  # Associate RT with subnet
  $subnet.RouteTable = $RouteTableObj
  $vNet | Set-AzVirtualNetwork
}

function Add-CustomRoutes {
  param ([Parameter(Mandatory = $true)] $RouteTableObj, [Parameter(Mandatory = $true)] $customRoutes)
  Write-Output "Adding custom routes to Route Table: $($RouteTableObj.Name)"

  $RouteTableObj = Get-AzRouteTable -Name $RouteTableObj.Name
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
  Write-Output "Deleting custom routes from Route Table: $($RouteTableObj.Name)"

  $RouteTableObj = Get-AzRouteTable -Name $RouteTableObj.Name
  foreach ($customRoute in $customRoutes) {
    Remove-AzRouteConfig -Name $customRoute.routeName -RouteTable $RouteTableObj
  }

  Set-AzRouteTable -RouteTable $RouteTableObj
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

$mode = funccullspaces($mode)
# $routeTableNames = funccullspaces($routeTableNames)
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
      if ($resourceGroup -notmatch "(-NETWORK-|^Hyperion|[-]Network|[-]NET[-]|-SKENSE-)") {
        Write-Error "Incorrect resource group. Resource group name must include one of the following patterns: *-NETWORK-*, *-Network, *-NET-*, Hyperion*, or *-SKENSE-*."
        break
      } 
      else {
        # foreach ($routeTableName in $routeTableNames) {
          Write-Output "Creating new Route Table: $routeTableName in Resource Group: $resourceGroup"
          if ($TagRouteTableManager) {
            $RouteTableObj = New-AzRouteTable -Name $routeTableName -ResourceGroupName $resourceGroup -Location (Get-AzResourceGroup -Name $resourceGroup).Location -Tag @{ RouteTableManager = $TagRouteTableManager }
          } else {
            $RouteTableObj = New-AzRouteTable -Name $routeTableName -ResourceGroupName $resourceGroup -Location (Get-AzResourceGroup -Name $resourceGroup).Location 
          }
          Write-Output "Route Table created successfully."

          Add-LocalRoutes -RouteTable $RouteTableObj # Add LocalSubnet route and associate RT-Subnet. This is done first because it will be helpful in adding correct FW routes by #148 instead of #147

          AddorUpdate-StandardRoutes -RouteTable $RouteTableObj

          if ($customRoutes) {
            Add-CustomRoutes -RouteTable $RouteTableObj -CustomRoutes $customRoutes
          }
        # }
      } 
    }

    "addRoutes" {
      # foreach ($routeTableName in $routeTableNames) {
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
      # }
    }

    "deleteRoutes" {
      # foreach ($routeTableName in $routeTableNames) {
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
      # }
    }

    "delete" {
      # foreach ($routeTableName in $routeTableNames) {
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
      # }
    }

    "update" {
      # foreach ($routeTableName in $routeTableNames) {
        $RouteTableObj = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName

        if ($RouteTableObj) {
          Write-Output "Updating Route Table: $routeTableName"
          AddorUpdate-StandardRoutes -RouteTable $RouteTableObj
        } else {
          Write-Error "Route Table $routeTableName does not exist."
        }
      # }
    }
  }
}