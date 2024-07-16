## https://learn.microsoft.com/en-us/answers/questions/930983/get-the-list-of-all-vms-with-disaster-recovery-act



Connect-AzAccount

$subscriptions = Get-AzSubscription

$results = @()

foreach ($subscription in $subscriptions) {
    
    Set-AzContext -SubscriptionId $subscription.Id

$vaults = Get-AzRecoveryServicesVault

foreach ($vault in $vaults) {
    
    Set-AzRecoveryServicesAsrVaultContext -Vault $vault

$fabrics = Get-AzRecoveryServicesAsrFabric

foreach ($fabric in $fabrics) {
    
    $container = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric
    
    $items= Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container

foreach ($item in $items) {

        if ($item -ne $null) {
        
        $vm = get-azvm | Where-Object { $_.Name -match $item.FriendlyName}
        
            $result = [PSCustomObject]@{
                "Subscription" = $subscription.Name
                "RecoveryVault" = $vault.Name
                "VirtualMachineName" = $item.FriendlyName
                "ActiveLocation" = $item.ActiveLocation
                "ProtectionState" = $item.ProtectionState
                "ReplicationHealth" = $item.ReplicationHealth

            } 
            $results += $result
            } 

} 

} 
} 

} 

$results | Export-Csv -Path "~/Downloads/file1.csv" -NoTypeInformation