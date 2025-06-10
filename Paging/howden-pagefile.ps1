$resultsarray =@()
$subs = "ec057239-e4b9-4f3a-bb91-769e0d722e04","9066859d-cbcd-4bc9-9f42-4f073763a256","32dd3ccd-29f1-4527-a887-8146d858a329" # HGS-INFRA-PROD, HGS-DATATECH-BDC-PREPROD & HGS-INFRA-DEVTEST

foreach ($sub in $subs){
Select-AzSubscription -SubscriptionId $sub

$nics = Get-AzNetworkInterface

foreach ($nic in $nics) {
if(($nic.VirtualMachine.Id -ne $null) -and ($nic.Primary -eq $true)){
$vnetname = $nic.IpConfigurations[0].Subnet.Id.split("/")[-3]
if(($vnetname -eq "VNET1-EU-North") -or ($vnetname -eq "VNET1-EU-West") -or ($vnetname -eq "VNET-DEVTEST-NE01") -or ($vnetname -eq "VNET-DEVTEST-UKS01") -or ($vnetname -eq "VNET-PROD-UKS01") ){

$object = New-Object –TypeName PSObject
$object | Add-Member –MemberType NoteProperty –Name VMName –Value $nic.VirtualMachine.Id.split("/")[-1]
#$object | Add-Member –MemberType not –Name VNet –Value $vnetname

$resultsarray += $object
}
}
}
}

foreach ($result in $resultsarray) { 
 
$result.VMName
$filelocation = get-wmiobject -computer $result.VMName Win32_pagefileusage | % {$_.Name} 
$drives = get-wmiobject -computer $result.VMName  Win32_LogicalDisk # | % {$_.VolumeName} 


foreach ($drive in $drives){

if ($drive.VolumeName -like 'Temporary Storage'){

$tempdriveletter = $drive.DeviceID
$tempdriveletter


$object = New-Object –TypeName PSObject
$object | Add-Member –MemberType NoteProperty –Name VMName –Value $result.VMName
$object | Add-Member –MemberType NoteProperty –Name PageFileLocation –Value $filelocation
$object | Add-Member –MemberType NoteProperty –Name TempDriveLetter –Value $tempdriveletter

$resultsarray += $object

}
}

}

$resultsarray | select VMName,PageFileLocation,TempDriveLetter | ft
$resultsarray| select VMName,PageFileLocation,TempDriveLetter | Export-csv ./PageFileLocations1.csv -notypeinformation

#get-wmiobject -computer "asr-prod-ne02"  Win32_LogicalDisk # | % {$_.Name} 

$cleanedresultsarray =@()

foreach ($results in $resultsarray){

if ($results.TempDriveLetter.Split(':')[0] -notlike $results.PageFileLocation.Split(':')[0]) {

#$tempdriveletter = $drive.DeviceID
#$tempdriveletter


$object = New-Object –TypeName PSObject
$object | Add-Member –MemberType NoteProperty –Name VMName –Value $results.VMName
$object | Add-Member –MemberType NoteProperty –Name PageFileLocation –Value $results.PageFileLocation
$object | Add-Member –MemberType NoteProperty –Name TempDriveLetter –Value $results.TempDriveLetter

$cleanedresultsarray += $object

}
}

$cleanedresultsarray

$cleanedresultsarray| select VMName,PageFileLocation,TempDriveLetter | Export-csv ./PageFileLocations2.csv -notypeinformation