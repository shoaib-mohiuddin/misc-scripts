function Validate-RouteTables {
    param ( [Parameter(Mandatory = $true)] [ref] $RT_Report )
    $RG_Compliance = ""
    $RT_Compliance = ""
    # $RT_Report = @()
    # $subscriptions = Get-AzSubscription 
    $subscription = Get-AzSubscription -SubscriptionName $subscriptionName

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
                if (($reportTable.Name -notcontains "*-PALO-*") -and ($routeTable.Name -notcontains "RT-PROD-GW-*")) {
                    if ($routeTable.ResourceGroupName -notlike "*-NETWORK-*") {
                        Write-Output "$($routeTable.Name) is in Incorrect resource group $($routeTable.ResourceGroupName)"
                        $RG_Compliance = "Incorrect resource group"
                    } 
                    else {
                        Write-Output "$($routeTable.Name) is in Correct resource group $($routeTable.ResourceGroupName)"
                        $RG_Compliance = "Correct resource group"
                    }
                }
                # if ($routeTable.ResourceGroupName -notlike "*-NETWORK-*") {
                #     Write-Output "$($routeTable.Name) is in Incorrect resource group $($routeTable.ResourceGroupName)"
                #     $RG_Compliance = "Incorrect resource group"
                # } 
                # else {
                #     Write-Output "$($routeTable.Name) is in Correct resource group $($routeTable.ResourceGroupName)"
                #     $RG_Compliance = "Correct resource group"
                # }

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
                                $missingRoutes += $dbRoute.Name
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

                    if ($missingRoutes) {
                        Write-Output "Missing routes in $($routeTable.Name):"
                        $missingRoutes | Format-Table
                        # $extraRoutes | Format-Table
                        # $RT_Compliance = "Route table non-compliant with DB"
                        $RT_Report.Value = $RT_Report.Value + [PSCustomObject]@{
                            SubscriptionName = $subscription.Name
                            ResourceGroupName = $routeTable.ResourceGroupName
                            RouteTableName = $routeTable.Name
                            RG_Compliance = $RG_Compliance
                            # RT_Compliance = $RT_Compliance
                            MissingRoutes = $missingRoutes 
                            # ExtraRoutes = $extraRoutes
                        }
                    } else { 
                        Write-Output "No missing routes in $($routeTable.Name)" 
                    }
                }
            }
        }
    # }
    Write-Output "Route Table Compliance Report:" 
    $RT_Report | Format-Table
}





$reportTable = $RT_Report | Format-Table
$subject = "[TEST] Route Table misconfigurations detected "  + $date

$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

####################################################################################################################
$body = $reportTable | ConvertTo-Html -head $Header | Out-String
$table_txt = $body
# $table_txt = $table_txt.Replace(' ', '@@@')
# $subject = $subject.Replace(' ', '@@@')

$EmailFrom = "AzureAutomation@service.howdengrp.com"
$EmailTo = Get-AutomationVariable -Name 'CloudreachPagerDuty'
$ToName = "CloudreachPagerDuty"
$params = [ordered]@{"Key1"=$EmailTo;"Key2"="$table_txt";"Key3"=$EmailFrom;"Key4"=$subject;"Key5"=$ToName}
Select-AzSubscription -SubscriptionId "ec057239-e4b9-4f3a-bb91-769e0d722e04"
Start-AzAutomationRunbook -AutomationAccountName "AUTOACC-PROD-IT-OPS" -Name "Communication-Services" -ResourceGroupName "RG-PROD-IT-AUTOMATION-NE01" -Parameters $params