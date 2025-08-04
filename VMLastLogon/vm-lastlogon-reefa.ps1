param (
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionName
)

Import-Module Az.Accounts -MinimumVersion
Import-Module Az.Compute

$ErrorActionPreference = "Stop"

try {
    Write-Output "Logging in to Azure..."
    Connect-AzAccount -Identity
    Set-AzContext -Subscription $SubscriptionName
    Write-Output "Successfully logged into subscription: $SubscriptionName"
} catch {
    Write-Error -Message "Failed to log in to Azure using Managed Identity: $($_.Exception.Message)"
    throw "Azure login failed."
}

Write-Output "Getting Windows VMs in subscription: $SubscriptionName..."
try {
    $vms = Get-AzVM | Where-Object { $_.StorageProfile.OSDisk.OsType -eq "Windows" }
    Write-Output "Found $($vms.Count) Windows VMs to process."
} catch {
    Write-Error -Message "Failed to retrieve VMs: $($_.Exception.Message)"
    throw "VM retrieval failed."
}

$vmLoginInfo = @()

foreach ($vm in $vms) {
    try {
        Write-Output "Running last login query on VM: $($vm.Name) in $($vm.ResourceGroupName)..."
        
        $script = @"
# Get last login using WMIC
`$wmicResult = wmic PATH Win32_NetworkLoginProfile GET Name,LastLogon /FORMAT:List

`$username = "N/A"
`$lastLogonTime = "N/A"
`$mostRecentLogon = [DateTime]::MinValue

# Parse WMIC output to find the most recent logon
foreach (`$line in `$wmicResult) {
    if (`$line -match "^Name=(.+)$") {
        `$currentName = `$matches[1]
    } elseif (`$line -match "^LastLogon=(.+)$") {
        `$currentLastLogonStr = `$matches[1]
        if (`$currentLastLogonStr -ne "") {
            try {
                # Convert CIM_DATETIME to DateTime object
                # Format is YYYYMMDDHHMMSS.ffffff+UUU or YYYYMMDDHHMMSS.ffffff-UUU
                # Need to handle potential fractional seconds and timezone info
                `$datePart = `$currentLastLogonStr.Substring(0, 14) # YYYYMMDDHHMMSS
                `$parsedDate = [datetime]::ParseExact(`$datePart, "yyyyMMddHHmmss", [System.Globalization.CultureInfo]::InvariantCulture)

                if (`$parsedDate -gt `$mostRecentLogon) {
                    `$mostRecentLogon = `$parsedDate
                    `$username = `$currentName
                    `$lastLogonTime = `$parsedDate.ToString("MM/dd/yyyy HH:mm:ss") # Standardize format
                }
            } catch {
                # Ignore parsing errors for individual lines
            }
        }
    }
}

if (`$username -ne "N/A") {
    Write-Output "User: `$username, LastLogin: `$lastLogonTime"
} else {
    Write-Output "No recent login found via WMIC"
}
"@

        $result = Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName `
                                        -Name $vm.Name `
                                        -CommandId 'RunPowerShellScript' `
                                        -ScriptString $script -ErrorAction Stop

        if ($result.Value) {
            $rawOutput = $result.Value[0].Message.Trim()
            Write-Output "Raw login output from $($vm.Name): $rawOutput"
            
            if ($rawOutput -match "User: (.+), LastLogin: (.+)") {
                $username = $matches[1]
                $lastLogin = $matches[2]
                
                $vmLoginInfo += [pscustomobject]@{
                    SubscriptionName = $SubscriptionName
                    VMName           = $vm.Name
                    ResourceGroup    = $vm.ResourceGroupName
                    LastLoginUser    = $username
                    LastLoginTime    = $lastLogin
                }
            } else {
                Write-Warning "Could not parse login output for VM $($vm.Name): '$rawOutput'"
                $vmLoginInfo += [pscustomobject]@{
                    SubscriptionName = $SubscriptionName
                    VMName           = $vm.Name
                    ResourceGroup    = $vm.ResourceGroupName
                    LastLoginUser    = "No recent login found"
                    LastLoginTime    = ""
                }
            }
        } else {
            Write-Warning "No result returned from Invoke-AzVMRunCommand for $($vm.Name)"
            $vmLoginInfo += [pscustomobject]@{
                SubscriptionName = $SubscriptionName
                VMName           = $vm.Name
                ResourceGroup    = $vm.ResourceGroupName
                LastLoginUser    = "No result returned"
                LastLoginTime    = ""
            }
        }
    } catch {
        Write-Warning "Failed to process VM $($vm.Name): $($_.Exception.Message)"
        $vmLoginInfo += [pscustomobject]@{
            SubscriptionName = $SubscriptionName
            VMName           = $vm.Name
            ResourceGroup    = $vm.ResourceGroupName
            LastLoginUser    = "Error retrieving data"
            LastLoginTime    = ""
        }
    }
}

Write-Output "Total VMs processed: $($vmLoginInfo.Count)"

$date = Get-Date -Format "dd-MM-yyyy"
$csvContent = $vmLoginInfo | ConvertTo-Csv -NoTypeInformation
$csvString = ($csvContent | Out-String).Trim()

Write-Output "CSV Content Generated:"
Write-Output $csvString

$csvBytes = [System.Text.Encoding]::UTF8.GetBytes($csvString)
$base64Content = [Convert]::ToBase64String($csvBytes)

Write-Output "Base64 content length: $($base64Content.Length)"

$subject = "VM Last Login Info Report - $SubscriptionName - $date"
$emailFrom = "AzureAutomation@service.howdengrp.com"
$emailTo = "reefa.begum@cloudreach.com"
$toName = "Reefa Begum"
$endpoint = "https://autoacc-prod-it-ops-comm-service.europe.communication.azure.com" 


if ($vmLoginInfo.Count -gt 0) {
    $htmlBody = @"
<html>
<body>
    <p>Dear Team,</p>
    <p>Please find the attached VM Last Login Info Report for subscription <strong>$SubscriptionName</strong>.</p>
    <p>Review the login details and take necessary action if required.</p>
    <p><strong>Total Windows VMs processed: $($vmLoginInfo.Count)</strong></p>
    <p>Report generated on: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss")</p>
    <br>
    <p>Best regards,</p>
    <p>Azure Automation</p>
</body>
</html>
"@
} else {
    $htmlBody = @"
<html>
<body>
    <p>Dear Team,</p>
    <p>No Windows VM login data was collected from subscription <strong>$SubscriptionName</strong>.</p>
    <p>Report generated on: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss")</p>
    <br>
    <p>Best regards,</p>
    <p>Azure Automation</p>
</body>
</html>
"@
}

Write-Output "Starting email sending process..."
Write-Output "Attempting Azure Communication Services REST API with attachment..."

$emailRequest = @{
    content = @{
        subject = $subject
        html = $htmlBody
    }
    recipients = @{
        to = @(
            @{
                address = $emailTo
                displayName = $toName
            }
        )
    }
    senderAddress = $emailFrom
    attachments = @(
        @{
            name = "VMLastLoginReport-$date.csv"
            contentType = "text/csv"
            contentInBase64 = $base64Content
        }
    )
}

$requestBody = $emailRequest | ConvertTo-Json -Depth 10

try {
    $tokenObject = Get-AzAccessToken -ResourceUrl "https://communication.azure.com/" -ErrorAction Stop
    $token = $tokenObject.Token
    Write-Output "Successfully obtained access token for Azure Communication Services."

    $headers = @{
        'Authorization' = "Bearer $token"
        'Content-Type' = 'application/json'
    }
    
    $uri = "$endpoint/emails:send?api-version=2023-03-31"
    Write-Output "Sending email request to URI: $uri"
    Write-Output "Request Body length: $($requestBody.Length)"
    
    $response = Invoke-RestMethod -Uri $uri -Method POST -Body $requestBody -Headers $headers -Verbose -ErrorAction Stop
    
    Write-Output "SUCCESS: Email with CSV attachment sent via Azure Communication Services REST API!"
    Write-Output "Message ID: $($response.id)"
    Write-Output "Status: $($response.status)"

} catch {
    Write-Error "EMAIL SENDING FAILED: $($_.Exception.Message)"
    Write-Output "Please ensure the Managed Identity running this script has 'Azure Communication Services Email Sender' or 'Contributor' role assigned on the Azure Communication Service resource '$endpoint'."
    Write-Output "Also verify that '$emailFrom' is a valid and configured sender email address in your Azure Communication Service domain."
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorContent = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorContent)
        $responseBody = $reader.ReadToEnd()
        
        Write-Output "HTTP Status Code: $statusCode"
        Write-Output "Response Body: $responseBody"
    }
    
    throw "Failed to send email with attachment. Check permissions and sender address."
}