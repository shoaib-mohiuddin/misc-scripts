try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

function Validate-RouteTables {
    param ( [Parameter(Mandatory = $true)] [ref] $RT_Report )
    $RG_Compliance = ""
    $RT_Compliance = ""
    # $RT_Report = @()
    # $subscriptions = Get-AzSubscription
    $subscription = Get-AzSubscription -SubscriptionName "DUAL-INFRA-PREPROD"

    # foreach ($subscription in $subscriptions) {
        Set-AzContext -SubscriptionId $subscription.Id
        $Tags = $subscription.Tags
        if ($Tags["SubscriptionType"] -ne "DatacenterExtension") {
            Write-Output "Subscription $($subscription.Name) is not tagged with SubscriptionType=DatacenterExtension. Exiting."
        } 
        else {
            Write-Output "Subscription $($subscription.Name) is tagged with SubscriptionType=DatacenterExtension. Proceeding..."
            $routeTables = Get-AzRouteTable
            # $routeTable = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName
            foreach ($routeTable in $routeTables) {
                if (($reportTable.Name -notlike "*-PALO-*") -and ($routeTable.Name -notlike "RT-PROD-GW-*")) {
                    if ($routeTable.ResourceGroupName -notlike "*-NETWORK-*") {
                        Write-Output "$($routeTable.Name) is in Incorrect resource group $($routeTable.ResourceGroupName)"
                        $RG_Compliance = "Incorrect resource group"
                    } 
                    else {
                        Write-Output "$($routeTable.Name) is in Correct resource group $($routeTable.ResourceGroupName)"
                        $RG_Compliance = "Correct resource group"
                    }
                }
                
                if (($routeTable.Name -notlike "*-PALO-*") -and ($routeTable.Name -notlike "RT-PROD-GW-*")) {
                    Write-Output "Validating route table $($routeTable.Name) ..."
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

                    Write-Output "Checking for missing routes..."
                    foreach ($dbRoute in $dbRoutes) {
                        if (($dbRoute.Region -eq 'all') -or ($dbRoute.Region -eq $routeTable.Location)) {
                            $match = $currentRoutes | Where-Object {
                                $_.Name -eq $dbRoute.Name -and
                                $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
                                $_.NextHopType -eq $dbRoute.NextHopType
                            }
                        
                            if (-not $match) {
                                # Write-Output "Missing route found: $($dbRoute.Name)"
                                $missingRoutes += $dbRoute.Name
                            }
                        }
                    }

                    if ($missingRoutes) {
                        Write-Output "Missing routes found"
                        # Write-Output "Missing routes in $($routeTable.Name):"
                        # $missingRoutes | Format-Table
                        # $RT_Compliance = "Route table non-compliant with DB"
                        $RT_Report.Value += [PSCustomObject]@{
                            SubscriptionName = $subscription.Name
                            ResourceGroupName = $routeTable.ResourceGroupName
                            RouteTableName = $routeTable.Name
                            RG_Compliance = $RG_Compliance
                            # RT_Compliance = $RT_Compliance
                            MissingRoutes = $missingRoutes -join ", "
                        }
                    } else { 
                        Write-Output "No missing routes in $($routeTable.Name)" 
                    }
                }
            }
        }
    # }
    Write-Output "Route Table Compliance Report:(inside function block)" 
    $RT_Report.Value | Format-Table
}



$date = get-date -format "dd-MM-yyyy"
$sqlcreds = Get-AutomationPSCredential -Name 'sql-prod-it-automation-ne01.database.windows.net'
$RT_Report = @()
Validate-RouteTables -RT_Report ([ref] $RT_Report)

Write-Output "Route Table Compliance Report:(outside function block)" 
$RT_Report | Format-Table -AutoSize
Write-Output "RT_Report Count: $($RT_Report.Count)"

# $reportTable = $RT_Report | Format-Table
$subject = "[TEST] Route Table misconfigurations detected " + $date

$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

####################################################################################################################
$body = $RT_Report | ConvertTo-Html -Head $Header | Out-String
# $body = $reportTable | ConvertTo-Html -Head $Header | Out-String
$table_txt = $body.Replace(' ', '@@@')
# $table_txt = [string]$table_txt
$subject = $subject.Replace(' ', '@@@')

$EmailFrom = "AzureAutomation@service.howdengrp.com"
$EmailTo = "shoaib.mohiuddin@cloudreach.com"
$ToName = "CloudreachSupport"
$params = [ordered]@{"Key1"=$EmailTo;"Key2"=$EmailFrom;"Key3"=$subject;"Key4"=$ToName}

Select-AzSubscription -SubscriptionId "ec057239-e4b9-4f3a-bb91-769e0d722e04"
Set-AzAutomationVariable -ResourceGroupName "RG-PROD-IT-AUTOMATION-NE01" -AutomationAccountName "AUTOACC-PROD-IT-OPS" -Name "RouteTableReport" -Value $table_txt -Encrypted $False
Start-AzAutomationRunbook -AutomationAccountName "AUTOACC-PROD-IT-OPS" -Name "TEST-Comm-Service" -ResourceGroupName "RG-PROD-IT-AUTOMATION-NE01" -Parameters $params
