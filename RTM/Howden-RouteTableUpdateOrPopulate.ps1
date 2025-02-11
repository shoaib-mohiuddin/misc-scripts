Param(
    [Parameter(Mandatory = $true)]
    [string] $SubscriptionName,
    [Parameter(Mandatory = $true)]
    [string[]] $RouteTablestoupdate # expected format: ["RT1Name","RT2Name"]
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

$SubscriptionName = funccullspaces($SubscriptionName)
$RouteTablestoupdate = funccullspaces($RouteTablestoupdate)

#$RouteTablestoupdate = "SA","NE","EA","UKS","WE" #,"RT-SUB-HSL-UAT-SKENSE-AGW-WE","RT-SUB-HSSC-PROD-SKENSE-AGW-NE","RT-SUB-HSSC-PROD-SKENSE-AGW-WE"

$sqlcreds = Get-AutomationPSCredential -Name 'sql-prod-it-automation-ne01.database.windows.net'

#select-azurermsubscription -subscriptionname $SubscriptionName
select-azsubscription -subscriptionname $SubscriptionName

#$RouteTablestoupdate

foreach ($RouteTableName in $RouteTablestoupdate) {
    #$RouteTableName
	
	if (($RouteTableName -notcontains "*-PALO-*") -and ($RouteTableName -notcontains "RT-PROD-GW-*")){
    
    $RTResourceObj = Get-AzRouteTable -Name $RouteTableName
    $RouteTableObJ = Get-AzRouteTable -ResourceGroupName $RTResourceObj.ResourceGroupName -Name $RTResourceObj.Name
    #$RTResourceObj = Get-AzureRmRouteTable -Name $RouteTableName
    #$RouteTableObJ = Get-AzureRmRouteTable -ResourceGroupName $RTResourceObj.ResourceGroupName -Name $RTResourceObj.Name
    

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
                    #Add-AzureRmRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $GatewayIP -RouteTable $RouteTableObJ
                    Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $GatewayIP -RouteTable $RouteTableObJ
                }            
                if (($dbroute.NextHopType -eq "VnetLocal") -and ($dbroute.NetxtHopIP -eq 'notapplicable' )) {
                    #Add-AzureRmRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -RouteTable $RouteTableObJ
                    Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -RouteTable $RouteTableObJ
                }
                if (($dbroute.NextHopType -eq "VirtualAppliance") -and ($dbroute.NetxtHopIP -ne 'regionspecific' )) {
                    #Add-AzureRmRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $dbroute.NetxtHopIP -RouteTable  $RouteTableObJ
                    Add-AzRouteConfig -Name $dbroute.Name -AddressPrefix $dbroute.AddressPrefix -NextHopType $dbroute.NextHopType -NextHopIpAddress $dbroute.NetxtHopIP -RouteTable  $RouteTableObJ
                }
                #Set-AzureRmRouteTable -RouteTable $RouteTableObJ
                Set-AzRouteTable -RouteTable $RouteTableObJ
            }
        }
    }
}
}