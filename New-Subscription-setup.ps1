Param(
    [Parameter(Mandatory = $true)]
    [string] $SubscriptionName,
	[Parameter(Mandatory = $true)]
	[ValidateSet('DatacenterExtension', 'OffNetwork')]
    [string] $SubscriptionType
)

#trim all spaces from the front and tail
function funccullspaces($param) {
    $param = $param.trim()
    $param = $param.replace(' ', '')
    return $param
}

Import-Module Az.Accounts
Import-Module Az.Automation
#Import-Module Az.Compute
Import-Module Az.Resources
Import-Module Az.Monitor
Import-Module Az.Security

Disable-AzContextAutosave -Scope Process
#$AzureContext = (Connect-AzAccount -Identity).context
try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
#$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContex

$sub = Get-AzSubscription -subscriptionName $SubscriptionName

Select-AzSubscription -SubscriptionId $sub.id  -TenantId $sub.TenantId

Register-AzResourceProvider -ProviderNamespace Microsoft.ManagedServices # For Lighthouse
Register-AzResourceProvider -ProviderNamespace Microsoft.PolicyInsights
Register-AzResourceProvider -ProviderNamespace Microsoft.Security
Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
Register-AzResourceProvider -ProviderNamespace Microsoft.Web
Register-AzResourceProvider -ProviderNamespace Microsoft.Network
Register-AzResourceProvider -ProviderNamespace Microsoft.Sql
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
Register-AzResourceProvider -ProviderNamespace Microsoft.insights
Register-AzResourceProvider -ProviderNamespace Microsoft.SqlVirtualMachine
Register-AzResourceProvider -ProviderNamespace Microsoft.EventGrid
Register-AzProviderFeature -FeatureName BulkRegistration -ProviderNamespace Microsoft.SqlVirtualMachine
Register-AzProviderFeature -FeatureName "EncryptionAtHost" -ProviderNamespace "Microsoft.Compute" 

$currentSub = Get-AzContext
$Scope = "/subscriptions/$($currentSub.Subscription.Id)"

#SOC Activity Log Export
Add-AzLogProfile -name "default" -ServiceBusRuleId "/subscriptions/ec057239-e4b9-4f3a-bb91-769e0d722e04/resourceGroups/RG-PROD-SOC-NE01/providers/Microsoft.EventHub/namespaces/EH-PROD-SOC-NE01/authorizationrules/RootManageSharedAccessKey"`
-RetentionInDays 3 -Category Write, Delete, Action -Location australiacentral, australiacentral2, australiaeast, australiasoutheast, brazilsouth, canadacentral, canadaeast, centralindia, centralus, eastasia, eastus, eastus2, francecentral, francesouth, germanynorth, germanywestcentral, japaneast, japanwest, koreacentral, koreasouth, northcentralus, northeurope, southafricanorth, southafricawest, southcentralus, southindia, southeastasia, uaecentral, uaenorth, uksouth, ukwest, westcentralus, westeurope, westindia, westus, westus2, global


$Tags = @{"SubscriptionType"="$SubscriptionType"}
New-AzTag -ResourceId $Scope -Tag $Tags

# Run this only if PALO-ALTO app registration is required [check with Andy/David]
#$ER = [System.Windows.Forms.MessageBox]::Show("Express Route Connectivity?" , "Express Route " , 4, 64)
#if ($SubscriptionType -eq 'DatacenterExtension') {

#Palo Panorama Intergration
#$subscription = $currentSub.Name
#$appName = "$subscription-PaloAltoPanoramaIntergration"
#$myApp = New-AzADServicePrincipal -Role "reader" -Scope "/subscriptions/$($scope.Subscription.Id)" -DisplayName $appName
#$supersecure = convertfrom-securestring -SecureString $myApp.Secret
#$object = New-Object –TypeName PSObject
#$object | Add-Member –MemberType NoteProperty –Name Subscription –Value $subscription
#$object | Add-Member –MemberType NoteProperty –Name DisplayName –Value $myApp.DisplayName
#$object | Add-Member –MemberType NoteProperty –Name ApplicationId –Value $myApp.ApplicationId
#$object | Add-Member –MemberType NoteProperty –Name Secret –Value $supersecure
#$resultsarray += $object
#}

#$resultsarray   

Start-Sleep -Seconds 600

Set-AzSecurityContact -Name "default" -Email "SecurityTeamNotification@hyperiongrp.com" -AlertAdmin -NotifyOnAlert 
#[System.Windows.MessageBox]::Show('Add SecurityTeamNotification@hyperiongrp.com to Security Center > Security policy Settings > Sub Name > Email notifications')
