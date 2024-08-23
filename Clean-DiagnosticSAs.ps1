try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

####################################################################################################################
function Clear-SA ($saResourceGroup, $sa) { 

$resultsarray =@()

$sakeys = (Get-AzStorageAccountKey -ResourceGroup $saResourceGroup -AccountName $sa).Value
$sakey = $sakeys[0]

$context = New-AzureStorageContext -StorageAccountName $sa -StorageAccountKey $sakey

$containers = Get-AzureStorageContainer -Context $context

foreach ($container in $containers) {

Remove-AzureStorageContainer -Name $container.Name -Context $context -Force

 }
}

Select-AzSubscription -SubscriptionId "9066859d-cbcd-4bc9-9f42-4f073763a256" #HYPX-INFRA-PREPROD
Clear-SA "RG-DEV-ITSERV-NE01" "strstandevnediagnostics"
Clear-SA "RG-DEV-ITSERV-UKS01" "strstandevuksdiagnostics"

Select-AzSubscription -SubscriptionId "ec057239-e4b9-4f3a-bb91-769e0d722e04" #HSL-INFRA-PROD
Clear-SA "RG-PROD-ITSERV-NE01" "strstanprodnediagnostics"
Clear-SA "RG-PROD-ITSERV-WE01" "strstanprodwediagnostics"
Clear-SA "RG-PROD-ITSERV-UKS01" "strstanproduksdiag"

Select-AzSubscription -SubscriptionId "7b0c1a06-7dca-4a4b-80e0-ed464f0d92ba" #DUAL-INFRA-PREPROD
Clear-SA "RG-DUAL-INFRA-PREPROD-DIAGS-NE01" "strstandulppnediag01"
Clear-SA "RG-DUAL-INFRA-PREPROD-DIAGS-WE01" "strstandulppwediag01"

Select-AzSubscription -SubscriptionId "b1e0c27d-d7c2-4020-856b-d602c425a580" #DUAL-INFRA-PROD
Clear-SA "RG-DUAL-INFRA-PROD-DIAGS-NE01" "strstandulprdnediag01"
Clear-SA "RG-DUAL-INFRA-PROD-DIAGS-WE01" "strstandulprdwediag01"


Select-AzSubscription -SubscriptionId "d4395077-1602-4a57-a8ee-649e9038e6b3" #HUK-INFRA-DEVTEST
Clear-SA "RG-HUK-INFRA-DEVTEST-DIAGS-NE01" "strstanhukdevnediag01"
Clear-SA "RG-HUK-INFRA-DEVTEST-DIAGS-WE01" "strstandulprdwediag01"

Select-AzSubscription -SubscriptionId "6b8d49b9-531d-4a2e-b7ec-5b0a923c5328" #HUK-INFRA-PROD
Clear-SA "RG-HUK-INFRA-PROD-DIAGS-NE01" "strstanhukprodnediag01"
Clear-SA "RG-HUK-INFRA-PROD-DIAGS-UKS01" "strstanhukproduksdiag01"
Clear-SA "RG-HUK-INFRA-PROD-DIAGS-WE01" "strstanhukprodwediag01"

Select-AzSubscription -SubscriptionId "9565839b-cc69-461f-960f-ce4d2949c9a9" #HSL-INFRA-PROD-ASIA
Clear-SA "RG-HSL-INFRA-PROD-DIAGS-EA01" "ststanhslprodeadiag01"
Clear-SA "RG-HSL-INFRA-PROD-DIAGS-SA01" "ststanhslprodsadiag01"

Select-AzSubscription -SubscriptionId "5e89b32f-592f-423b-a834-8899fb0d9d66" #HAS-INFRA-PROD
Clear-SA "RG-HAS-INFRA-PROD-DIAGS-EA01" "ststanhasprodeadiag01"
Clear-SA "RG-HAS-INFRA-PROD-DIAGS-SA01" "ststanhasprodsadiag01"
