
Param(

    [Parameter(Mandatory = $false)]
    [string] $SubscriptionName,
    [Parameter(Mandatory = $false)]
    [string] $Location,
	[Parameter(Mandatory = $false)]
    [string] $vnetName,
    [Parameter(Mandatory = $false)]
    [string] $centraldiagaccount,
    [Parameter(Mandatory = $false)]
    [string] $diagSA,
    [Parameter(Mandatory = $false)]
    [string] $prodvaultname,
    [Parameter(Mandatory = $false)]
    [string] $prodvaultdefaultpolname,
    [Parameter(Mandatory = $false)]
    [string] $nonprodvaultname,
    [Parameter(Mandatory = $false)]
    [string] $nonprodvaultdefaultpolname

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


select-azsubscription -subscriptionname $SubscriptionName
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
$prodvaultname = funccullspaces ($prodvaultname)
$prodvaultdefaultpolname = funccullspaces ($prodvaultdefaultpolname)
$nonprodvaultname = funccullspaces ($nonprodvaultname)
$nonprodvaultdefaultpolname= funccullspaces ($nonprodvaultdefaultpolname)

$SubscriptionName = $SubscriptionName.ToUpper()
#$Location = $Location.ToLower()

Invoke-Sqlcmd -Query "INSERT INTO dbo.Provisioning (Subscription, Location, vnetName, centraldiagaccount, diagSA, prodvaultname, prodvaultdefaultpolname, nonprodvaultname, nonprodvaultdefaultpolname) VALUES ('$SubscriptionName', '$Location', '$vnetName', '$centraldiagaccount', '$diagSA', '$prodvaultname', '$prodvaultdefaultpolname', '$nonprodvaultname', '$nonprodvaultdefaultpolname'); " `
    -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20


$configdbreturn = Invoke-Sqlcmd -Query "SELECT * From dbo.Provisioning WHERE Subscription='$SubscriptionName'; " `
    -ServerInstance "sql-autoacc-test.database.windows.net" -Credential $sqlcreds -Database "sql-autoacc-test" -QueryTimeout 20

write-Output "Config DB request return"
write-Output $configdbreturn
