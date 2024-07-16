#import-module Az.Accounts

#try {
#    "Logging in to Azure..."
#    Connect-AzAccount -Identity
#}
#catch {
#    Write-Error -Message $_.Exception
#    throw $_.Exception
#}

# $resultsarray = @()

# $subs = Get-AzSubscription

# foreach ($sub in $subs) {
# Select-AzSubscription -SubscriptionId $sub.Id -Tenant "3c18fb64-72f3-4131-8803-2f3bfbb39c84"
# $AllRGs = (Get-AzResourceGroup).ResourceGroupName
# $UsedRGs = (Get-AzResource | Group-Object ResourceGroupName).Name
# $EmptyRGs = $AllRGs | Where-Object { $_ -notin $UsedRGs }

# foreach ($RG in $EmptyRGs) {

# $object = New-Object -TypeName PSObject
# $object | Add-Member -MemberType NoteProperty -Name RG -Value $RG
# $object | Add-Member -MemberType NoteProperty -Name Sub -Value $sub.Name
# $resultsarray += $object

# }
# }

# $resultsarray| ft

# echo $resultsarray
# #$resultsarray| Export-csv c:\temp\EmptyResourceGroups.csv -notypeinformation

#----------------------------------

$Subscriptions = Get-AzSubscription

foreach ($sub in $Subscriptions) {
    Select-AzSubscription -SubscriptionId $sub.Id -Tenant "3c18fb64-72f3-4131-8803-2f3bfbb39c84"
    $resourceGroups = Get-AzResourceGroup
    foreach ($resourceGroup in $ResourceGroups) {
        $ResourceGroupName = $resourceGroup.ResourceGroupName
        $count = (Get-AzResource | Where-Object{ $_.ResourceGroupName -match $ResourceGroupName }).Count
        if ($count -eq 0) {
            Write-Host "$ResourceGroupName has no resources. Writing to CSV file."
            Get-AzResourceGroup -ResourceGroupName $ResourceGroupName | Select-Object ResourceGroupName, Location | Export-Csv -Path "$($sub.name)-EmtpyRG.csv" -append
        }
    }
}

#-------------------------------------

#login to your Azure Account
#Connect-AzureRmAccount
#Once the subscription is set, execute the following command
#$rgs = Get-AzureRmResourceGroup;
#foreach($resourceGroup in $rgs){
#    $name = $resourceGroup.ResourceGroupName;
#    $count = (Get-AzureRmResource | Where-Object{ $_.ResourceGroupName -match $name }).Count;
#    if($count -eq 0){
#        Write-Output $name | Out-File -FilePath ‘file.csv’ -Append
#    }
#}
