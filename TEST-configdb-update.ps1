Param(
    [Parameter(Mandatory = $false)]
    [string] $SubscriptionName,
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroup,
    [Parameter(Mandatory = $false)]
    [string] $Location,
    [Parameter(Mandatory = $false)]
    [string] $vnetName,
    [Parameter(Mandatory = $false)]
    [string] $vnetAddressPrefix,
    [Parameter(Mandatory = $false)]
    [string] $centraldiagaccount,
    [Parameter(Mandatory = $false)]
    [string] $diagSA,
    # [Parameter(Mandatory = $false)]
    # [string] $prodvaultname,
    # [Parameter(Mandatory = $false)]
    # [string] $prodvaultdefaultpolname,
    # [Parameter(Mandatory = $false)]
    # [string] $nonprodvaultname,
    # [Parameter(Mandatory = $false)]
    # [string] $nonprodvaultdefaultpolname,
    [Parameter(Mandatory = $false)]
    [string] $nextHopType,
    [Parameter(Mandatory = $false)]
    [string] $hubName,
    [Parameter(Mandatory = $false)]
    [string] $nextHopIP
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

Import-Module Az.Accounts
Import-Module Az.Automation
Import-Module Az.Resources


Select-AzSubscription -subscriptionname $SubscriptionName
$sqlcreds = Get-AutomationPSCredential -Name 'sql-autoacc-test.database.windows.net' 

#trim all spaces from the front and tail
function funccullspaces($param) {
    $param = $param.trim()
    $param = $param.replace(' ', '')
    return $param
}

$SubscriptionName = funccullspaces ($SubscriptionName)
$Location = funccullspaces ($Location)
$vnetName = funccullspaces ($vnetName)
$centraldiagaccount = funccullspaces ($centraldiagaccount)
$diagSA = funccullspaces ($diagSA)
$vnetAddressPrefix = funccullspaces ($vnetAddressPrefix)
$nextHopType = funccullspaces ($nextHopType)
$hubName = funccullspaces ($hubName)
$nextHopIP = funccullspaces ($nextHopIP)
$prodvaultname = 'commvault'
$prodvaultdefaultpolname = 'commvault'
$nonprodvaultname = 'commvault'
$nonprodvaultdefaultpolname= 'commvault'

$SubscriptionName = $SubscriptionName.ToUpper()
$ResourceGroup = $ResourceGroup.ToUpper()
$vnetName = $vnetName.ToUpper()
$hubName = $hubName.ToUpper()
$Location = $Location.ToLower()

# UPDATE LOCKS DB TABLE
if ($ResourceGroup -and $SubscriptionName) {
    Invoke-Sqlcmd -Query "INSERT INTO dbo.Locks (ReourceGroupName, SubscriptionName) VALUES ('$ResourceGroup', '$SubscriptionName'); " `
        -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20
}
$lockdbreturn = Invoke-Sqlcmd -Query "SELECT * From dbo.Locks WHERE SubscriptionName='$SubscriptionName'; " `
    -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20

Write-Output "Lock DB request return"
Write-Output $lockdbreturn

# UPDATE PROVISIONING DB TABLE
if ($vnetName -and $Location -and $centraldiagaccount -and $diagSA ) {
    Invoke-Sqlcmd -Query "INSERT INTO dbo.Provisioning (Subscription, Location, vnetName, centraldiagaccount, diagSA, prodvaultname, prodvaultdefaultpolname, nonprodvaultname, nonprodvaultdefaultpolname) VALUES ('$SubscriptionName', '$Location', '$vnetName', '$centraldiagaccount', '$diagSA', '$prodvaultname', '$prodvaultdefaultpolname', '$nonprodvaultname', '$nonprodvaultdefaultpolname'); " `
        -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20
}
$provisioningdbreturn = Invoke-Sqlcmd -Query "SELECT * From dbo.Provisioning WHERE Subscription='$SubscriptionName'; " `
    -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20

Write-Output "Provisioning DB request return"
Write-Output $provisioningdbreturn

# UPDATE ROUTES DB TABLE
if ($vnetName -and $vnetAddressPrefix -and $nextHopType -and $hubName -and $nextHopIP -and $Location -in @("westeurope", "northeurope", "uksouth")) {
    Invoke-Sqlcmd -Query "INSERT INTO dbo.Routes (Name, AddressPrefix, NextHopType, HubName, NetxtHopIP, Region) VALUES ('$vnetName', '$vnetAddressPrefix', '$nextHopType', '$hubName', '$nextHopIP', 'all'); " `
        -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20
}
if ($vnetName -and $vnetAddressPrefix -and $nextHopType -and $hubName -and $nextHopIP -and $Location -notin @("westeurope", "northeurope", "uksouth")) {
    Invoke-Sqlcmd -Query "INSERT INTO dbo.Routes (Name, AddressPrefix, NextHopType, HubName, NetxtHopIP, Region) VALUES ('$vnetName', '$vnetAddressPrefix', '$nextHopType', '$hubName', '$nextHopIP', '$Location'); " `
        -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20
}
$routesdbreturn = Invoke-Sqlcmd -Query "SELECT * From dbo.Routes WHERE Name='$vnetName'; " `
    -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20

Write-Output "Routes DB request return"
Write-Output $routesdbreturn