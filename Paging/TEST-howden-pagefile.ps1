param ()

try {
  "Logging in to Azure..."
  Connect-AzAccount -Identity
}
catch {
  Write-Error -Message $_.Exception
  throw $_.Exception
}

Select-AzSubscription -SubscriptionId "ec057239-e4b9-4f3a-bb91-769e0d722e04"
# $vmarray = @("AA-D-APP-NE01", "AA-D-BOT-NE01", "AA-D-TS-NE01")
$vmarray = @()
$nics = Get-AzNetworkInterface

foreach ($nic in $nics) {
  if(($nic.VirtualMachine.Id -ne $null) -and ($nic.Primary -eq $true)){
    $vnetname = $nic.IpConfigurations[0].Subnet.Id.split("/")[-3]
    if(($vnetname -eq "VNET1-EU-North") -or ($vnetname -eq "VNET1-EU-West") -or ($vnetname -eq "VNET-DEVTEST-NE01") -or ($vnetname -eq "VNET-DEVTEST-UKS01") -or ($vnetname -eq "VNET-PROD-UKS01") ){

      $object = New-Object –TypeName PSObject
      $object | Add-Member –MemberType NoteProperty –Name VMName –Value $nic.VirtualMachine.Id.split("/")[-1]
      #$object | Add-Member –MemberType not –Name VNet –Value $vnetname

      $vmarray += $object
      $vmarray
    }
  }
}

foreach ($vm in $vmarray) {
  try {
    Write-Output "Processing VM: $vm"
    
    # Run PageFileUsage command
    $pagefileResult = Invoke-AzVMRunCommand -ResourceGroupName 'rg-dev-app-rpa-ne01' `
      -VMName $vm `
      -CommandId 'RunPowerShellScript' `
      -ScriptString "Get-WmiObject Win32_PageFileUsage | Select-Object Name"

    # Output page file result
    Write-Output "Page File Location for ${vm}: $($pagefileResult.Value[0].Message)"

    # Run LogicalDisk command
    $diskResult = Invoke-AzVMRunCommand -ResourceGroupName 'rg-dev-app-rpa-ne01' `
      -VMName $vm `
      -CommandId 'RunPowerShellScript' `
      -ScriptString "Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, FileSystem, Size, FreeSpace | ConvertTo-Json -Depth 3"

    # Output disk result
    $diskObjects = $diskResult.Value[0].Message | ConvertFrom-Json
    foreach ($disk in $diskObjects) {
      if ($disk.VolumeName -eq 'Temporary Storage') {
        Write-Output "Temporary Drive Letter for ${vm}: $($disk.DeviceID)"
      }
    }
  }
  catch {
    Write-Error -Message "Error processing VM ${vm}: $_"
  }
}

# # Run PageFileUsage command
# $pagefileResult = Invoke-AzVMRunCommand -ResourceGroupName 'rg-dev-app-rpa-ne01' `
#   -VMName 'AA-D-APP-NE01' `
#   -CommandId 'RunPowerShellScript' `
#   -ScriptString "Get-WmiObject Win32_PageFileUsage | Select-Object Name"

# # Output page file result
# $pagefileResult.Value[0].Message

# # Run LogicalDisk command
# $diskResult = Invoke-AzVMRunCommand -ResourceGroupName 'rg-dev-app-rpa-ne01' `
#   -VMName 'AA-D-APP-NE01' `
#   -CommandId 'RunPowerShellScript' `
#   -ScriptString "Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, FileSystem, Size, FreeSpace | ConvertTo-Json -Depth 3"
# # Output disk result
# $diskResult.Value[0].Message | ConvertFrom-Json
# $diskObjects = $diskResult.Value[0].Message | ConvertFrom-Json

# # foreach ($disk in $diskObjects) {
# #     Write-Output $disk.VolumeName
# # }

# foreach ($disk in $diskObjects) {
#   if ($disk.VolumeName -eq 'Temporary Storage') {
#     $tempDriveLetter = $disk.DeviceID
#     Write-Output "Temporary Drive Letter: $tempDriveLetter"
#   }
# }