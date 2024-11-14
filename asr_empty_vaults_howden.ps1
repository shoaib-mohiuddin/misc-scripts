Connect-AzAccount

$subscriptions = Get-AzSubscription
$results = @()

foreach ($subscription in $subscriptions) {

    Set-AzContext -SubscriptionId $subscription.Id

    $vaults = Get-AzRecoveryServicesVault

    foreach ($vault in $vaults) {
        
        Set-AzRecoveryServicesAsrVaultContext -Vault $vault

        # Check Backup Items --- AzureVM and AzureStorage 
        $vmContainers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.ID -ErrorAction SilentlyContinue
        $storageContainers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureStorage -VaultId $vault.ID -ErrorAction SilentlyContinue

        # Check Replicated Items 
        $allReplicatedItems = @()
        $fabrics = Get-AzRecoveryServicesAsrFabric
        foreach ($fabric in $fabrics) {
            $containers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric -ErrorAction SilentlyContinue

            foreach ($container in $containers) {
                $replicatedItems = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container -ErrorAction SilentlyContinue
                if ($replicatedItems) {
                    $allReplicatedItems += $replicatedItems
                }
            }
        }

        if (-not $vmContainers -and -not $storageContainers -and -not $allReplicatedItems) {
            $result = [PSCustomObject]@{
                "Subscription"       = $subscription.Name
                "RecoveryVaultName"  = $vault.Name
                "ResourceGroupName"  = $vault.ResourceGroupName
                "Location"           = $vault.Location
            }
            $results += $result
        }
    }
}

$results | Export-Csv -Path "~/Downloads/asr_empty_vaults_howden.csv" -NoTypeInformation
