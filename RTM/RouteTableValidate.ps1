<#
.SYNOPSIS
  Azure Automation runbook to validate route tables and generate a compliance report.

.DESCRIPTION
  This script performs validation of route tables across all DatacenterExtension
  subscriptions. It checks for:
  - Correct resource group placement (resource group name must have '*-NETWORK-*' )
  - Missing standard routes as defined in the database
  - Extra routes not defined in the standard configuration
    
  The runbook generates a detailed compliance report and emails it to specified recipients using
  Azure Communication Services.

.PARAMETER None
  This runbook does not accept any parameters.

.NOTES
  Automation Account: AUTOACC-PROD-IT-OPS
  Runbook:            RouteTableAudit
  Author:             Shoaib Mohiuddin
  Purpose:            Route Table CI - RITM0026549

  Database Dependencies:
  - Server: sql-prod-it-automation-ne01.database.windows.net
  - Database: DB-PROD-OPS-AUTOMATION-NE01
  - Table: dbo.Routes (contains standard routes configuration)
  - Database credential 'sql-prod-it-automation-ne01.database.windows.net' stored in Automation Account Credentials

  Email Dependencies:
  - Uses Azure Communication Services AUTOACC-PROD-IT-OPS-COMM-SERVICE for email delivery

.OUTPUTS
  - Console output of runbook execution progress
  - HTML formatted email report containing non-compliant route tables

.LINK
  https://cloudreach.jira.com/wiki/spaces/CO/pages/5368283168/Route+Table+Validation
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

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

function Validate-RouteTables {
    param ( [Parameter(Mandatory = $true)] [ref] $RT_Report )
    $RG_Compliance = ""
    $subscriptions = Get-AzSubscription | Where-Object { $_.Tags["SubscriptionType"] -eq "DatacenterExtension" }
    # $subscriptions = Get-AzSubscription -SubscriptionName "DUAL-INFRA-PREPROD"

    foreach ($subscription in $subscriptions) {
        Set-AzContext -SubscriptionId $subscription.Id
        $routeTables = Get-AzRouteTable | Where-Object { $_.Name -notlike "*-PALO-*" -and $_.Name -notlike "RT-PROD-GW-*" }
        foreach ($routeTable in $routeTables) {
            if ($routeTable.ResourceGroupName -notlike "*-NETWORK-*") {
                Write-Output "$($routeTable.Name) is in Incorrect resource group $($routeTable.ResourceGroupName)"
                $RG_Compliance = "Incorrect resource group"
            } 
            else {
                Write-Output "$($routeTable.Name) is in Correct resource group $($routeTable.ResourceGroupName)"
                $RG_Compliance = "Correct resource group"
            }
            
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
            
            $hubVNets = @("VNET1-EU-North", "VNET1-EU-West", "VNET-PROD-UKS01", "VNET-HSL-INFRA-PROD-SA01", "VNET-HSL-INFRA-PROD-EA01", "VNET-HGS-INFRA-PROD-AE01", "VNET-HGS-INFRA-PROD-UC01", "VNET-HGS-INFRA-PROD-UE01")

            # Get the vNet in which the RT exists
            # $vNet = (Get-AzVirtualNetwork | Where-Object { $_.Subnets.Name -eq ($routeTable.Name -replace "^RT-", "") }).Name

            # $vNet = ((Get-AzRouteTable -Name $routeTable).SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 8
            $vNet = ($routeTable.SubnetsText | ConvertFrom-Json).Id -split '/' | Select-Object -Index 8

            $currentRoutes = $routeTable.Routes
            # Compare routes
            $missingRoutes = @()
            $extraRoutes = @()


            Write-Output "Checking for missing routes..."
            foreach ($dbRoute in $dbRoutes) {
                if (($dbRoute.Region -eq 'all') -or ($dbRoute.Region -eq $routeTable.Location)) {
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
                    if ($dbRoute.Name -notlike "PA-P-FW-*") {                                               #All other routes
                        $match = $currentRoutes | Where-Object {
                            $_.Name -eq $dbRoute.Name -and
                            $_.AddressPrefix -eq $dbRoute.AddressPrefix -and
                            $_.NextHopType -eq $dbRoute.NextHopType -and
                            $_.NextHopIpAddress -eq $GatewayIP
                        }
                    }
                
                    if (-not $match) {
                        $missingRoutes += $dbRoute.Name
                    }
                }
            }

            foreach ($currentRoute in $currentRoutes) {
                if (($currentRoute.Name -notlike "PA-P-FW-*") -and ($currentRoute.Name -notlike "LocalSubnet")) {
                    $match = $dbRoutes | Where-Object {
                        $_.Name -eq $currentRoute.Name # -and
                        # $_.AddressPrefix -eq $currentRoute.AddressPrefix -and
                        # $_.NextHopType -eq $currentRoute.NextHopType
                    }
                
                    if (-not $match) {
                        $extraRoutes += $currentRoute.Name
                    }
                }
            }

            if ($missingRoutes -or $extraRoutes) {
                Write-Output "Missing routes found"
                $RT_Report.Value += [PSCustomObject]@{
                    SubscriptionName = $subscription.Name
                    ResourceGroupName = $routeTable.ResourceGroupName
                    RouteTableName = $routeTable.Name
                    RG_Compliance = $RG_Compliance
                    MissingRoutes = $missingRoutes -join ", "   # newline character - "`n"
                    ExtraRoutes = $extraRoutes -join ", "   # newline character - "`n"
                }
            } else { 
                Write-Output "No missing routes in $($routeTable.Name)" 
            }
        }
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# $date = get-date -format "dd-MM-yyyy"
$sqlcreds = Get-AutomationPSCredential -Name 'sql-prod-it-automation-ne01.database.windows.net'
$RT_Report = @()
Validate-RouteTables -RT_Report ([ref] $RT_Report)

Write-Output "Route Table Compliance Report:" 
$RT_Report | Format-Table -AutoSize
Write-Output "RT_Report Count: $($RT_Report.Count)"

$subject = "Route Table Compliance Report " # + $date
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

$body = $RT_Report | ConvertTo-Html -Head $Header | Out-String
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

$message = @{
    ContentSubject = $subject
    RecipientTo = @($emailRecipientTo)
    SenderAddress = $emailFrom
    ContentHtml = $body
}

try {
    $poller = Send-AzEmailServicedataEmail -Message $Message -endpoint $endpoint # It should be $Message and not $message as with latter it is failing
    $result = $poller.Result
    Write-Output "Email sent successfully."
} catch {
    Write-Error "Error sending email: $_"
}
