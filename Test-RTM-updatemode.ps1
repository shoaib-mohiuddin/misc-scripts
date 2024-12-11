"update" {
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

                            $dbRoutes = Invoke-Sqlcmd -Query "SELECT * From dbo.Routes WHERE (hubname like '$Hub'); " -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "DB-AUTOACC-TEST-NE01" -QueryTimeout 20

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
        else {
            "No Route Table misconfigurations were found"
        }