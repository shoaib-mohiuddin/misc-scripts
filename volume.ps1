# List the disks for NVMe volumes

function Get-EC2InstanceMetadata {
    param([string]$Path)
    (Invoke-WebRequest -Uri "http://169.254.169.254/latest/$Path").Content 
}

function GetEBSVolumeId {
    param($Path)
    $SerialNumber = (Get-Disk -Path $Path).SerialNumber
    if($SerialNumber -clike 'vol*'){
        $EbsVolumeId = $SerialNumber.Substring(0,20).Replace("vol","vol-")
    }
    else {
       $EbsVolumeId = $SerialNumber.Substring(0,20).Replace("AWS","AWS-")
    }
    return $EbsVolumeId
}

function GetDeviceName{
    param($EbsVolumeId)
    if($EbsVolumeId -clike 'vol*'){
    
        $Device  = ((Get-EC2Volume -VolumeId $EbsVolumeId ).Attachment).Device
        $VolumeName = ""
    }
     else {
        $Device = "Ephemeral"
        $VolumeName = "Temporary Storage"
    }
    Return $Device,$VolumeName
}

function GetDriveLetter{
    param($Path)
    $DiskNumber =  (Get-Disk -Path $Path).Number
    if($DiskNumber -eq 0){
        $VirtualDevice = "root"
        $DriveLetter = "C"
        $PartitionNumber = (Get-Partition -DriveLetter C).PartitionNumber
    }
    else
    {
        $VirtualDevice = "N/A"
        $DriveLetter = (Get-Partition -DiskNumber $DiskNumber).DriveLetter
        if(!$DriveLetter)
        {
            $DriveLetter = ((Get-Partition -DiskId $Path).AccessPaths).Split(",")[0]
			#$DriveLetter = ((Get-Partition -DiskId $Path).AccessPaths -join ',')
        } 
        $PartitionNumber = (Get-Partition -DiskId $Path).PartitionNumber   
    }
    
    return $DriveLetter,$VirtualDevice,$PartitionNumber

}


function GetSize{
	
	param($Path)
	$freedisksize=Get-WmiObject -Class Win32_LogicalDisk |
		Select-Object -Property DeviceID, @{Label='FreeSpace (Gb)'; expression={($_.FreeSpace/1GB).ToString('F2')}},
		@{Label='Total (Gb)'; expression={($_.Size/1GB).ToString('F2')}},
		@{Label='Used (Gb)'; expression={[Math]::Round(($_.Size/1GB).ToString('F2') - ($_.FreeSpace/1GB).ToString('F2'), 2)}},
		@{Label='FreePercent'; expression={[Math]::Round(($_.freespace / $_.size) * 100, 2)}},
		@{Label='InstanceID'; expression={Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id}}	

	$freedisksize| Export-Csv 'C:\Users\Administrator\Documents\output.csv' -NoTypeInformation  -Append
	

}

$Report = @()
foreach($Path in (Get-Disk).Path)
{
    $Disk_ID = ( Get-Partition -DiskId $Path).DiskId
    $Disk = ( Get-Disk -Path $Path).Number
    $EbsVolumeId  = GetEBSVolumeId($Path)
    $Size =(Get-Disk -Path $Path).Size
    $DriveLetter,$VirtualDevice, $Partition = (GetDriveLetter($Path))
    $Device,$VolumeName = GetDeviceName($EbsVolumeId)
	$InstanceId = Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id
    $DiskObject = New-Object PSObject -Property @{
      Disk          = $Disk
      DriveLetter   = $DriveLetter -join ','
      EbsVolumeId   = $EbsVolumeId 
      Device        = $Device 
      VirtualDevice = $VirtualDevice
	  InstanceID    = $InstanceId	
    }
	#$Report += $Disk
	$DiskObject | Export-Csv 'C:\Users\Administrator\Documents\output1.csv' -NoTypeInformation -Append
	
} 

#$Report | Sort-Object Disk | Format-Table -AutoSize -Property Disk, DriveLetter, EbsVolumeId, Device, VirtualDevice

GetSize($Path)





# Define an array to store results
$results = @()

# Get all Azure subscriptions
$subscriptions = Get-AzSubscription

foreach ($subscription in $subscriptions) {
    # Select the current subscription
    Select-AzSubscription -SubscriptionId $subscription.Id

    Write-Host "Processing subscription: $($subscription.Name)"

    # Get all resource groups in the current subscription
    $allResourceGroups = Get-AzResourceGroup

    $emptyResourceGroups = @()

    foreach ($resourceGroup in $allResourceGroups) {
        $resources = Get-AzResource -ResourceGroupName $resourceGroup.ResourceGroupName

        if ($resources.Count -eq 0) {
            $asrResources = $resources | Where-Object { $_.ResourceType -eq "Microsoft.RecoveryServices/vaults" }

            if ($asrResources.Count -eq 0) {
                $emptyResourceGroups += [PSCustomObject]@{
                    ResourceGroupName = $resourceGroup.ResourceGroupName
                    SubscriptionName   = $subscription.Name
                }
            }
        }
    }

    if ($emptyResourceGroups.Count -eq 0) {
        Write-Host "No empty resource groups with ASR found in subscription $($subscription.Name)."
    } else {
        Write-Host "Empty resource groups with ASR in subscription $($subscription.Name):"
        $emptyResourceGroups | Format-Table -Property ResourceGroupName, SubscriptionName -AutoSize

        # Output to the console doesn't change the underlying data structure
        # Add the result objects to the array
        $results += $emptyResourceGroups
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path "Users/shoaib.mohiuddin/Downloads/ASR_empty_RGs.csv" -NoTypeInformation






# Define an array to store results
$results = @()

# Get all Azure subscriptions
$subscriptions = Get-AzSubscription

foreach ($subscription in $subscriptions) {
    # Select the current subscription
    Select-AzSubscription -SubscriptionId $subscription.Id

    Write-Host "Processing subscription: $($subscription.Name)"

    # Get all resource groups in the current subscription
    $allResourceGroups = Get-AzResourceGroup

    $emptyResourceGroups = @()

    foreach ($resourceGroup in $allResourceGroups) {
        $resources = Get-AzResource -ResourceGroupName $resourceGroup.ResourceGroupName

        if ($resources.Count -eq 0) {
            $asrResources = $resources | Where-Object { $_.ResourceType -eq "Microsoft.RecoveryServices/vaults" }

            if ($asrResources.Count -eq 0) {
                $emptyResourceGroups += $resourceGroup.ResourceGroupName
            }
        }
    }

    if ($emptyResourceGroups.Count -eq 0) {
        Write-Host "No empty resource groups with ASR found in subscription $($subscription.Name)."
    } else {
        Write-Host "Empty resource groups with ASR in subscription $($subscription.Name):"
        $emptyResourceGroups

        # Create an object to represent the results
        $resultObject = [PSCustomObject]@{
            SubscriptionName      = $subscription.Name
            EmptyResourceGroups   = $emptyResourceGroups -join ', '
        }

        # Add the result object to the array
        $results += $resultObject
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path "~/Downloads/ASR_empty_RGs.csv" -NoTypeInformation
