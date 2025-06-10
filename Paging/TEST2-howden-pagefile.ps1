$subs = @(
    "ec057239-e4b9-4f3a-bb91-769e0d722e04"
)
$targetVnets = @("VNET1-EU-North", "VNET1-EU-West", "VNET-PROD-UKS01")
$finalResults = @()

foreach ($sub in $subs) {
    Write-Output "Switching to subscription: $sub"
    Select-AzSubscription -SubscriptionId $sub

    $nics = Get-AzNetworkInterface

    foreach ($nic in $nics) {
        if ($nic.VirtualMachine.Id -ne $null -and $nic.Primary -eq $true) {
            $vnetname = $nic.IpConfigurations[0].Subnet.Id.Split("/")[-3]

            if ($targetVnets -contains $vnetname) {
                $vmName = $nic.VirtualMachine.Id.Split("/")[-1]
                $rgName = $nic.VirtualMachine.Id.Split("/")[4]

                # Check if VM is Windows
                $vm = Get-AzVM -ResourceGroupName $rgName -Name $vmName -ErrorAction SilentlyContinue
                if ($vm.StorageProfile.OSDisk.OSType -ne "Windows") {
                    Write-Output "Skipping non-Windows VM: $vmName"
                    continue
                }

                try {
                    Write-Output "Processing Windows VM: $vmName in $vnetname"

                    # Get page file info
                    $pagefileResult = Invoke-AzVMRunCommand -ResourceGroupName $rgName `
                        -VMName $vmName `
                        -CommandId 'RunPowerShellScript' `
                        -ScriptString "Get-WmiObject Win32_PageFileUsage | Select-Object Name | ConvertTo-Json -Depth 2"

                    $pagefileInfo = $pagefileResult.Value[0].Message | ConvertFrom-Json
                    $pagefilePath = $pagefileInfo.Name

                    # Get disk info
                    $diskResult = Invoke-AzVMRunCommand -ResourceGroupName $rgName `
                        -VMName $vmName `
                        -CommandId 'RunPowerShellScript' `
                        -ScriptString "Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName | ConvertTo-Json -Depth 3"

                    $diskObjects = $diskResult.Value[0].Message | ConvertFrom-Json
                    if ($diskObjects -isnot [System.Collections.IEnumerable]) {
                        $diskObjects = @($diskObjects)
                    }

                    $tempDrive = $diskObjects | Where-Object { $_.VolumeName -eq 'Temporary Storage' }

                    if ($null -ne $tempDrive) {
                        Write-Output "Found Temporary Storage drive for $vmName"

                        $finalResults += [PSCustomObject]@{
                            VMName           = $vmName
                            PageFileLocation = $pagefilePath
                            TempDriveLetter  = $tempDrive.DeviceID
                            Division         = $vm.Tags["Division"]
                            Environment      = $vm.Tags["Environment"]
                        }
                    } else {
                        Write-Output "No Temporary Storage found for $vmName — skipping."
                    }
                }
                catch {
                    Write-Warning "Error processing $vmName: $_"
                }
            }
        }
    }
}

# Export to CSV
$csvFilePath = ".\WindowsVMs_With_TempStorage.csv"
$finalResults | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
$file_bytes = [System.IO.File]::ReadAllBytes($csvFilePath)
$date = Get-Date -format "dd/MM/yyyy"
$subject = "WindowsVMs_With_TempStorage - $date"
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

$emailAttachment = @(
  @{
    ContentInBase64 = $file_bytes
    ContentType = "text/csv"
    Name = "WindowsVMs_With_TempStorage-$date.csv"
  }
)
$message = @{
  ContentSubject = $subject
  RecipientTo = @($emailRecipientTo)
  SenderAddress = $emailFrom
  ContentHtml = "<html><body><p>Please find the attached WindowsVMs_With_TempStorage Report.</p><p>Please refer to the document linked below to take appropriate action based on the report findings:</p><p><a href='https://cloudreach.jira.com/wiki/spaces/CO/pages/5408751617/Action+on+Compliance+Report+Not+live+yet'>Action on Compliance Report</a></p></body></html>"
  Attachment = @($emailAttachment)
}

try {
  $poller = Send-AzEmailServicedataEmail -Message $Message -endpoint $endpoint
  $result = $poller.Result
  Write-Output "Email sent."
} catch {
  Write-Error "Error sending email: $_"
}