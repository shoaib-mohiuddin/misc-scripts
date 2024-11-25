Connect-AzAccount

$subscriptions = Get-AzSubscription

$results = @()

foreach ($subscription in $subscriptions) {

    Set-AzContext -SubscriptionId $subscription.Id

    $vaults = Get-AzRecoveryServicesVault

    foreach ($vault in $vaults) {

        Set-AzRecoveryServicesAsrVaultContext -Vault $vault

        $containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.ID
        if ($containers) {
            foreach ($container in $containers) {
                
                $items = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -VaultId $vault.ID

                    foreach ($item in $items) {
                        if ($item -ne $null) {
                            try {
                                $vm = Get-AzVM -Name $container.FriendlyName -ResourceGroupName $container.ResourceGroupName -ErrorAction Stop
                                $commvaultTag = if ($vm.Tags.ContainsKey("hgs-commvault-policy")) {
                                    $vm.Tags["hgs-commvault-policy"]
                                } else {
                                    " "
                                }
                            }
                            catch {
                                # Write-Host "VM '$($container.FriendlyName)' not found in resource group '$($container.ResourceGroupName)'. Error: $($_.Exception.Message)"
                                $commvaultTag = "VM Not Found"
                            }

                            $result = [PSCustomObject]@{
                                "Subscription"       = $subscription.Name
                                "RecoveryVault"      = $vault.Name
                                "VirtualMachineName" = $container.FriendlyName
                                "Status"             = $container.Status
                                "ProtectionStatus"   = $item.ProtectionStatus
                                "ProtectionState"    = $item.ProtectionState
                                "HealthStatus"       = $item.HealthStatus
                                "LastBackupTime"     = $item.LastBackupTime
                                "LastBackupStatus"   = $item.LastBackupStatus
                                "hgs-commvault-policy"    = $commvaultTag
                            }
                            $results += $result
                        }
                    }

            }
        }
    }
}

$results | Export-Csv -Path "~/Downloads/asr_backup_vms2.csv" -NoTypeInformation
