$subs = @(
    "ec057239-e4b9-4f3a-bb91-769e0d722e04"
)
$finalResults = @()

foreach ($sub in $subs) {

    Select-AzSubscription -SubscriptionId $sub

    $vms = Get-AzVM -Status | Where-Object { $_.StorageProfile.OSDisk.OsType -eq "Windows" -and $_.PowerState -eq "VM running" }

    foreach ($vm in $vms) {
      $vmlastlogon = Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName `
                      -VMName $vm.Name `
                      -CommandId 'RunPowerShellScript' `
                      -ScriptString @'
Get-WmiObject -Class Win32_NetworkLoginProfile | Select-Object Name,
    @{Name = "LastLogon"; Expression = {
        if ($_.LastLogon) {
            [System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastLogon)
        } else {
            "Never logged on"
        }
    }} | Sort-Object LastLogon -Descending
'@
      # Get the 'Message' field (which contains the text table)
      $message = $vmlastlogon.Value[0].Message

      # Split the message into lines and skip the first two (headers and separator)
      $lines = $message -split "`r?`n" | Select-Object -Skip 2

      # Parse the line that contains Name and LastLogon
      if ($lines.Count -ge 1 -and $lines[0] -match "^(?<Name>.+?)\s+(?<LastLogon>\d{1,2}/\d{1,2}/\d{4}.*)$") {
          $name = $matches['Name'].Trim()
          $lastLogon = $matches['LastLogon'].Trim()

          Write-Host "User: $name"
          Write-Host "Last Logon: $lastLogon"
      } else {
          Write-Host "Could not extract login info from message."
      }
    
      if ($null -ne $vmlastlogon) {
        $finalResults += [PSCustomObject]@{
            VMName           = $vm.Name
            LastLogonProfile = $name
            LastLogonTime    = $lastLogon
            Division         = $vm.Tags["Division"]
            Environment      = $vm.Tags["Environment"]
          }
      } else {}

    }
}

# Export to CSV
$csvFilePath = ".\WindowsVMs_LastLogon.csv"
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
    Name = "WindowsVMs_LastLogon-$date.csv"
  }
)
$message = @{
  ContentSubject = $subject
  RecipientTo = @($emailRecipientTo)
  SenderAddress = $emailFrom
  ContentHtml = "<html><body><p>Please find the attached WindowsVMs_LastLogon Report.</p><p>Please refer to the document linked below to take appropriate action based on the report findings:</p><p><a href='https://cloudreach.jira.com/wiki/spaces/CO/pages/5408751617/Action+on+Compliance+Report+Not+live+yet'>Action on Compliance Report</a></p></body></html>"
  Attachment = @($emailAttachment)
}

try {
  $poller = Send-AzEmailServicedataEmail -Message $Message -endpoint $endpoint
  $result = $poller.Result
  Write-Output "Email sent: $result"
} catch {
  Write-Error "Error sending email: $_"
}