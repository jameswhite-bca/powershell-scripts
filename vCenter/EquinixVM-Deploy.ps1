<#
.SYNOPSIS
Equinix-VMDeploy builds VMs from the BCA template to the new Equinix datacentre 
.DESCRIPTION 
Simply fill out the vmbuilds csv file with the required settings and the build will be completed to BCA standards
.PARAMETER csvpath
path to the csv which contains a list of configuration for the VMs
.EXAMPLE
.\Equinix-VMDeploy.ps1 -csvpath "D:\Temp\VMBuilds.csv"
.NOTES
.LINK
=======
version : 1.0.0
last updated: 06 July 2022
Author: James White, Robert Glass
.LINK
https://www.bca.co.uk
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Please provide the path to the csv file of new vms")]
    [string]$csvpath
)

#check that powercli is installed as it is required for the script to work
if (Get-Module -ListAvailable -Name VMware.PowerCLI) {
    Write-Host "Module exists"
} 
else {
    Write-Host "Installing Module"
    Install-Module -Name VMware.PowerCLI -Scope CurrentUser
}
# -- Script Variables; change for every deployment --
$vCenterAddress = 'pd-vcent-001.ad.bca.com'
$NewVMsDataInput = "CsvFile" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = $csvpath

$StartVMs = $true

#Set variables; VMs to deploy
<#Example
Template,Name,Folder,ResourcePool,Datastore,CPU,RAM,HDD1Size,Network,IPMode,IPAddress,Subnet,Gateway,DNS1,DNS2,Password
201711-Win2012R2-STD-NSP,PB-TEST-2012,PB VMs,PB VMs,PROV-VMFS1 (15K SAS),2,8,80,PB Network - VLAN102,UseStaticIP,172.22.102.180,255.255.255.0,172.22.102.1,89.151.64.70,81.29.64.60,MyPassword35
201802-Win2016-STD-NSP,PB-TEST-2016,PB VMs,PB VMs,PROV-VMFS1 (15K SAS),2,8,100,PB Network - VLAN102,UseStaticIP,172.22.102.181,255.255.255.0,172.22.102.1,89.151.64.70,81.29.64.60,MyPassword35
#>
$NewVMsScriptInput = @'
Template,Name,Hostname,Folder,ResourcePool,Datastore,CPU,RAM,HDD1Size,Network,IPMode,IPAddress,Subnet,Gateway,DNS1,DNS2,Password,HDD1DiskFormat
202201-Win2019-STD-SP,JW-TEST-001,JW-TEST-001,Development,UAT Cluster,VMWUAT33,2,4,100,172.30.6.0,UseStaticIP,172.30.6.36,255.255.255.0,172.30.6.252,172.30.6.95,172.30.6.96,qb@4C5Gn&Mfi,Thin
'@ | ConvertFrom-Csv


$GuestCustomizationScripts = @()

<# Guest Customization Script Template
$GuestCustomizationScripts += @{
    'Category'=""
    'Order'=500
    'OSes'=@("","")
    'Code'=@'

'@
}
#>

# Guest Customization Script Headers
$GuestCustomizationScripts += @{
    'Category'="Header"
    'Order'=0
    'OSes'=@("Win2019","Win2016","Win2012R2","Win2008R2")
    'Code'=@'
@echo off
timeout 30
md C:\Users\Public\Desktop\PostInstallRunning
'@
}

$GuestCustomizationScripts += @{
    'Category'="Header"
    'Order'=0
    'OSes'=@("CentOS7","Ubuntu1604")
    'Code'=@'
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ x$1 = x"precustomization" ]; then
date > /var/log/vm-is-ready-pre
echo Do Precustomization tasks
echo Do Precustomization tasks complete
elif [ x$1 = x"postcustomization" ]; then
echo Do Postcustomization tasks
date > /var/log/vm-is-ready-post
'@
}

$GuestCustomizationScripts += @{
    'Category'="ExpandOSPartition"
    'Order'=100
    'OSes'=@("Win2019","Win2016","Win2012R2")
    'Code'=@'
Powershell -EncodedCommand UgBlAHMAaQB6AGUALQBQAGEAcgB0AGkAdABpAG8AbgAgAC0ARAByAGkAdgBlAEwAZQB0AHQAZQByACAAIgBDACIAIAAtAFMAaQB6AGUAIAAoACgARwBlAHQALQBQAGEAcgB0AGkAdABpAG8AbgBTAHUAcABwAG8AcgB0AGUAZABTAGkAegBlACAALQBEAHIAaQB2AGUATABlAHQAdABlAHIAIAAiAEMAIgApAC4AUwBpAHoAZQBNAGEAeAApAA==
'@
}

$GuestCustomizationScripts += @{
    'Category'="ExpandOSPartition"
    'Order'=100
    'OSes'=@("Win2008R2")
    'Code'=@'
echo select disk 0 >C:\BCA\extend.txt
echo select partition 2 >>C:\BCA\extend.txt
echo extend >>C:\BCA\extend.txt
diskpart /s C:\BCA\extend.txt
erase C:\BCA\extend.txt
'@
}

$GuestCustomizationScripts += @{
    'Category'="ExpandOSPartition"
    'Order'=100
    'OSes'=@("Ubuntu1604")
    'Code'=@'
! echo -e "d\n2\nn\np\n\n\n\nt\n2\n8e\nw" | fdisk /dev/sda
apt-get install parted -y
partprobe
pvresize /dev/sda2
lvextend -l +100%FREE /dev/mapper/vg_root-lv_root
resize2fs /dev/mapper/vg_root-lv_root
'@
}

$GuestCustomizationScripts += @{
    'Category'="ExpandOSPartition"
    'Order'=100
    'OSes'=@("CentOS7")
    'Code'=@'
! echo -e "d\n2\nn\np\n\n\n\nt\n2\n8e\nw" | fdisk /dev/sda
yum install parted -y
partprobe
pvresize /dev/sda2
lvextend -l +100%FREE /dev/mapper/vg_root-lv_root
resize2fs /dev/mapper/vg_root-lv_root
'@
}

$GuestCustomizationScripts += @{
    'Category'="AdditionalDisks"
    'Order'=105
    'OSes'=@("Win2019","Win2016","Win2012R2")
    'Code'=@'
<AdditionalDisks>
'@
}

$GuestCustomizationScripts += @{
    'Category'="SwapFile"
    'Order'=200
    'OSes'=@("CentOS7","Ubuntu1604")
    'Code'=@'
if [ ! -f /.swap ]; then dd if=/dev/zero of=/.swap bs=1M count=2048;fi
if ! ( swapon -s | grep -q /.swap ); then chmod 600 /.swap; mkswap /.swap; fi
if ! grep -q /.swap "/etc/fstab"; then echo /.swap none swap sw 0 0 >> /etc/fstab; fi
swapon -a
'@
}

$GuestCustomizationScripts += @{
    'Category'="SwapFileCustomization"
    'Order'=205
    'OSes'=@("CentOS7")
    'Code'=@'
swapoff -a
dd if=/dev/zero of=/.swap bs=1M count=5120
chmod 600 /.swap
mkswap /.swap
swapon -a
'@
}

$GuestCustomizationScripts += @{
    'Category'="OSLicense"
    'Order'=300
    'OSes'=@("Win2008R2")
    'Code'=@'
cscript C:\Windows\System32\slmgr.vbs /ato
'@
}

$GuestCustomizationScripts += @{
    'Category'="InstallAV"
    'Order'=750
    'OSes'=@("Win2019","Win2016","Win2012R2")
    'Code'=@'
<InstallAV>
'@
}

$GuestCustomizationScripts += @{
    'Category'="OSUpdate"
    'Order'=800
    'OSes'=@("Win2019","Win2016")
    'Code'=@'
Powershell -EncodedCommand JABTAE0AIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHIAdgBpAGMAZQBNAGEAbgBhAGcAZQByADsAJABTAE0ALgBDAGwAaQBlAG4AdABBAHAAcABsAGkAYwBhAHQAaQBvAG4ASQBEACAAPQAgACIATQB5ACAAQQBwAHAAIgA7ACQAUwBNAC4AQQBkAGQAUwBlAHIAdgBpAGMAZQAyACgAIgA3ADkANwAxAGYAOQAxADgALQBhADgANAA3AC0ANAA0ADMAMAAtADkAMgA3ADkALQA0AGEANQAyAGQAMQBlAGYAZQAxADgAZAAiACwANwAsACIAIgApAA==
timeout 15
PowerShell -EncodedCommand JABVAFMAIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHMAcwBpAG8AbgA7ACQAVQBTAHIAIAA9ACAAJABVAFMALgBDAHIAZQBhAHQAZQBVAHAAZABhAHQAZQBTAGUAYQByAGMAaABlAHIAKAApADsAJABTAFIAIAA9ACAAJABVAFMAcgAuAFMAZQBhAHIAYwBoACgAIgBJAHMASQBuAHMAdABhAGwAbABlAGQAPQAwACAAYQBuAGQAIABUAHkAcABlAD0AJwBTAG8AZgB0AHcAYQByAGUAJwAiACkAOwAkAEQATAAgAD0AIAAkAFUAUwAuAEMAcgBlAGEAdABlAFUAcABkAGEAdABlAEQAbwB3AG4AbABvAGEAZABlAHIAKAApADsAJABEAEwALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQARABMAC4ARABvAHcAbgBsAG8AYQBkACgAKQA7ACQASQBOACAAPQAgACQAVQBTAC4AQwByAGUAYQB0AGUAVQBwAGQAYQB0AGUASQBuAHMAdABhAGwAbABlAHIAKAApADsAJABJAE4ALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQASQBOAC4ASQBuAHMAdABhAGwAbAAoACkA
'@
}

$GuestCustomizationScripts += @{
    'Category'="OSUpdate"
    'Order'=800
    'OSes'=@("Win2012R2","Win2008R2")
    'Code'=@'
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 3 /f
Powershell -EncodedCommand JABTAE0AIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHIAdgBpAGMAZQBNAGEAbgBhAGcAZQByADsAJABTAE0ALgBDAGwAaQBlAG4AdABBAHAAcABsAGkAYwBhAHQAaQBvAG4ASQBEACAAPQAgACIATQB5ACAAQQBwAHAAIgA7ACQAUwBNAC4AQQBkAGQAUwBlAHIAdgBpAGMAZQAyACgAIgA3ADkANwAxAGYAOQAxADgALQBhADgANAA3AC0ANAA0ADMAMAAtADkAMgA3ADkALQA0AGEANQAyAGQAMQBlAGYAZQAxADgAZAAiACwANwAsACIAIgApAA==
timeout 15
PowerShell -EncodedCommand JABVAFMAIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHMAcwBpAG8AbgA7ACQAVQBTAHIAIAA9ACAAJABVAFMALgBDAHIAZQBhAHQAZQBVAHAAZABhAHQAZQBTAGUAYQByAGMAaABlAHIAKAApADsAJABTAFIAIAA9ACAAJABVAFMAcgAuAFMAZQBhAHIAYwBoACgAIgBJAHMASQBuAHMAdABhAGwAbABlAGQAPQAwACAAYQBuAGQAIABUAHkAcABlAD0AJwBTAG8AZgB0AHcAYQByAGUAJwAiACkAOwAkAEQATAAgAD0AIAAkAFUAUwAuAEMAcgBlAGEAdABlAFUAcABkAGEAdABlAEQAbwB3AG4AbABvAGEAZABlAHIAKAApADsAJABEAEwALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQARABMAC4ARABvAHcAbgBsAG8AYQBkACgAKQA7ACQASQBOACAAPQAgACQAVQBTAC4AQwByAGUAYQB0AGUAVQBwAGQAYQB0AGUASQBuAHMAdABhAGwAbABlAHIAKAApADsAJABJAE4ALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQASQBOAC4ASQBuAHMAdABhAGwAbAAoACkA
'@
}

$GuestCustomizationScripts += @{
    'Category'="OSUpdate"
    'Order'=800
    'OSes'=@("CentOS7")
    'Code'=@'
yum update -y
'@
}

$GuestCustomizationScripts += @{
    'Category'="OSUpdate"
    'Order'=800
    'OSes'=@("Ubuntu1604")
    'Code'=@'
apt-get update
apt-get dist-upgrade
apt-get upgrade
'@
}

$GuestCustomizationScripts += @{
    'Category'="Reboot"
    'Order'=900
    'OSes'=@("Win2019","Win2016","Win2012R2","Win2008R2")
    'Code'=@'
shutdown /r /t 10
'@
}

$GuestCustomizationScripts += @{
    'Category'="Shutdown"
    'Order'=900
    'OSes'=@("CentOS7","Ubuntu1604")
    'Code'=@'
shutdown -P 1
'@
}

$GuestCustomizationScripts += @{
    'Category'="Footer"
    'Order'=1000
    'OSes'=@("CentOS7","Ubuntu1604")
    'Code'=@'
fi
exit 0
'@
}

# -- Open connections --
#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true
#Connect to vCenter
$domaincreds = (Get-Credential -Message 'Enter your $ account domain credentials to login to vCenter')
$vmdomaincreds = (Get-Credential -Message 'Enter your domain credentials to join any VMs to the domain')
if (!$vCenterConnection) { $vCenterConnection = Connect-VIServer -Server $vCenterAddress -Force -ErrorAction Stop -Credential $domaincreds }
elseif ($vCenterConnection.IsConnected -ne $true) { $vCenterConnection = Connect-VIServer -Server $vCenterAddress -Force -ErrorAction Stop -Credential $domaincreds}
$localadminpwd = (Get-Credential -Message 'Enter the local admin password to the VMs' -UserName administrator)


# Collect Variables from file if needed, prompt user to select VMs to deploy
switch ($NewVMsDataInput) {
    Script {
        $NewVMs = $NewVMsScriptInput | Out-GridView -Passthru -Title "Select VMs to deploy:"
    }
    CsvFile {
        try {$null = Test-Path $NewVMsDataInputFilePath}
        catch {throw}
        $NewVMsFileInput = Get-Content -Raw -Path $NewVMsDataInputFilePath | ConvertFrom-CSV
        $NewVMs = $NewVMsFileInput | Out-GridView -Passthru -Title "Select VMs to deploy:"
    }
}

# Check user has selected VMs
if (!($NewVMs)) {Write-Host -ForegroundColor Red "No VMs have been selected, terminating."; throw}

#Check to see if VMs already exist
Write-Host "Checking to see if VMs already exist"
foreach ($VmExist in $NewVMs) {
    $DoesVmExist = get-vm -Name $VmExist.Hostname -ErrorAction 'SilentlyContinue'
    if ($DoesVmExist) {
        Write-Host -ForegroundColor Red $VmExist.Hostname "already exists!"
        Throw
    }
}

#Ensure existing matching profiles are removed so new customisation data is used

Write-Host "Checking if OS Profiles already exist and removing"
foreach ($VmCustRemove in $NewVMs) {
    $OsProfileExist = Get-OSCustomizationSpec $VmCustRemove.Hostname -ErrorAction 'SilentlyContinue'
    if ($OsProfileExist) {
        Remove-OSCustomizationSpec $VmCustRemove.Hostname -Confirm: $false
        Write-Host $VmCustRemove.Name "OS Profiles removed"     
    }
}

#Generate new OS customisation profiles
Write-Host "Creating OS customisation profile..."
foreach ($VMCust in $NewVMs) {
    $VMCustSpec = New-OSCustomizationSpec -Name $VMCust.Hostname -FullName 'Support' -OrgName 'BCA' -OSType Windows -ChangeSid -Domain $vmcust.DomainName -DomainCredentials $vmdomaincreds -TimeZone 085 -AutoLogonCount 1 -NamingPrefix $VMCust.Hostname -NamingScheme fixed -AdminPassword $localadminpwd.getnetworkcredential().password
    $VMCustSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -Position '1' -IpMode UseStaticIP -IpAddress $VMCust.IPAddress -SubnetMask $VMCust.Subnet -DefaultGateway $VMCust.Gateway -Dns $VMCust.DNS1, $VMCust.DNS2

    # Set Guest Customization Scripts
    switch ($VMCust.OS) { Win2019 { $NewVMTemplateOSType = "Windows" }  Win2016 { $NewVMTemplateOSType = "Windows" } Win2012R2 { $NewVMTemplateOSType = "Windows" } }
    switch ($NewVMTemplateOSType) { Windows {$CommentCharacter = "::" ; $NewVMGuestCustomizationScript = ""} Linux {$CommentCharacter = "#" ; $NewVMGuestCustomizationScript = "#!/bin/bash`n"} }
    $NewVMGuestCustomizationScriptModules = $GuestCustomizationScripts | Where-Object { $_.OSes -contains $VMCust.OS } | Sort-Object -Property "Order"
    foreach ($NewVMGuestCustomizationScriptModule in $NewVMGuestCustomizationScriptModules) {
        $NewVMGuestCustomizationScript += "`n" + $CommentCharacter + " " + $NewVMGuestCustomizationScriptModule.Category + " " + $NewVMGuestCustomizationScriptModule.Order + "`n"
        $NewVMGuestCustomizationScript += $NewVMGuestCustomizationScriptModule.Code + "`n"
    }
    #Build Array
    $NewDiskGuestCustomization = @()
    $NewDiskNumber = 0
    # Add disks
    if ($VMCust.HDDAdditional -and ($VMCust.OS -like "Win2019" -or $VMCust.OS -like "Win2016" -or $VMCustOS -like "Win2012R2")) {
        $NewDiskGuestCustomization += '$CDROM = Get-WmiObject win32_volume -filter "DriveType = 5" ; $CDROM.DriveLetter = $null ; $CDROM.Put()' #Unmount CD drive
        foreach ($NewDisk in $VMCust.HDDAdditional -split ";") {
            $NewDiskNumber ++
            $NewDiskProperties = $NewDisk -split ","
            $NewDiskDriveLetter = $NewDiskProperties[2]
            [string]$NewDiskFileSystemLabel = '"' + $NewDiskProperties[3] + '"'
            $NewDiskGuestCustomization += "Initialize-Disk -Number $NewDiskNumber -PartitionStyle GPT"
            $NewDiskGuestCustomization += "New-Partition -DiskNumber $NewDiskNumber -UseMaximumSize -DriveLetter $NewDiskDriveLetter"
            if ($NewDiskProperties[4]) {
                $NewDiskAllocationUnitSize = [int]$NewDiskProperties[4] * 1024
                $NewDiskGuestCustomization += "Format-Volume -DriveLetter $NewDiskDriveLetter -NewFileSystemLabel $NewDiskFileSystemLabel -AllocationUnitSize $NewDiskAllocationUnitSize"
            }
            else { $NewDiskGuestCustomization += "Format-Volume -DriveLetter $NewDiskDriveLetter -NewFileSystemLabel $NewDiskFileSystemLabel" }
        }
        $NewDiskGuestCustomization += '$CDROMLetter = [int][char]"C" ; WHILE((Get-PSDrive -PSProvider filesystem).Name -contains [char]$CDROMLetter){$CDROMLetter++}'
        $NewDiskGuestCustomization += '$CDROM.DriveLetter = "$([char]$CDROMLetter):" ; $CDROM.Put()'
    }
    
    $EncodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($NewDiskGuestCustomization -join ";"))
    if ($EncodedCommand) { [string]$NewDiskGuestCustomizationScript =  "Powershell -EncodedCommand " + $EncodedCommand }
    else { [string]$NewDiskGuestCustomizationScript = "" }

    if ($VMCust.AV -like "Armor" -and ($VMCust.OS -like "Win2016" -or $VMCust.OS -like "Win2016" -or $VMCustOS -like "Win2012R2")) {
        $AvGuestCustomization = $ArmorInstallString -replace "<AVLicenseKey>",$VMCust.AVData
    }

    $EncodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($AvGuestCustomization -join ";"))
    if ($EncodedCommand) { [string]$AvGuestCustomizationScript =  "Powershell -EncodedCommand " + $EncodedCommand }
    else { [string]$AvGuestCustomizationScript = "" }

    $NewVMGuestCustomizationScript = $NewVMGuestCustomizationScript `
        -replace "<AdditionalDisks>", $NewDiskGuestCustomizationScript `
        -replace "<InstallAV>", $AvGuestCustomizationScript
    
    if ($NewVMGuestCustomizationScript) {
        $NewVMGuestCustomizationArray = $NewVMGuestCustomizationScript -split "`r" -split "`n" | Where-Object {$_ -ne ""}
        $NewVMGuestCustomizationArrayWrapped = @()
        foreach ($Item in $NewVMGuestCustomizationArray) {
            [string]$Prefix = 'cmd /c "echo '
            [string]$Suffix = '>> C:\BCA\Customization.bat"'
            [string]$Item = $Prefix + $Item + $Suffix
            while ($Item.Length -ge 250) {
                [string]$SubItem = $Item.Substring(0,(250 - 2 - $Suffix.Length)) + "^^" + $Suffix
                $NewVMGuestCustomizationArrayWrapped += $SubItem
                [string]$Item = $Prefix + $Item.Substring(250 - 2 - $Suffix.Length)
            }
            $NewVMGuestCustomizationArrayWrapped += $Item
        }
        $NewVMGuestCustomizationArrayWrapped += 'cmd /c "C:\BCA\Customization.bat"'
        $NewVMGuestCustomizationArrayWrapped += 'cmd /c "erase C:\BCA\Customization.bat"'
        $VMCustSpec | Set-OSCustomizationSpec -GuiRunOnce ( $NewVMGuestCustomizationArrayWrapped )
    }
}

Start-Sleep -Seconds 5

# Deploy New VMs and set resources
Write-Host "Deploying VMs..."
foreach ($VMDeploy in $NewVMs) {
    $VMDeployObject = New-VM -Name $VMDeploy.Hostname -Template $VMDeploy.Template -OSCustomizationSpec $VMDeploy.Hostname -Datastore $VMDeploy.Datastore -Location $VMDeploy.Folder -ResourcePool $VMDeploy.ResourcePool -DiskStorageFormat Thick
    $VMDeployObject | Set-VM -MemoryGB $VMDeploy.RAM -NumCpu $VMDeploy.CPU -Confirm: $false -Notes $VMDeploy.Description
    $VMDeployObject | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $VMDeploy.Network -Confirm: $false
    switch ( $VMDeploy.Environment)
    {
        UAT  { $DrsClusterGroup = "UAT-VM's"  ; $dns1 = '172.30.6.95' ; $dns2 = '172.30.6.96' }
        PROD { $DrsClusterGroup = "Prod-VM's" ; $dns1 = '172.30.6.96' ; $dns2 = '172.30.6.96' }
        DEV  { $DrsClusterGroup = "DEV-VM's"  ; $dns1 = '172.30.6.96' ; $dns2 = '172.30.6.96' }
    }

    Set-DrsClusterGroup -DrsClusterGroup $DrsClusterGroup  -VM $VMDeploy.Hostname -Add
    if ($VMDeploy.HDDAdditional) {
        foreach ($NewDisk in $VMDeploy.HDDAdditional -split ";") {
            $NewDiskProperties = $NewDisk -split ","
            New-HardDisk -VM $VMDeployObject -CapacityGB $NewDiskProperties[0] #-StorageFormat  $NewDiskProperties[1]
        }
    }
    if ($StartVMs -eq $true) { Start-VM $VMDeploy.Hostname -Confirm:$False -ErrorAction:Stop }
}

# wait until VM has started
Write-Host "Waiting for VM's to start ..."
foreach ($WaitVMStart in $NewVMs) {
    while ($True) {
        $VmStartEvents = Get-VIEvent -Entity $WaitVMStart.Name
        $StartedEvent = $VmStartEvents | Where-Object { $_.GetType().Name -eq "VMStartingEvent" }
        if ($StartedEvent) {
            write-host -ForegroundColor Green $WaitVMStart.Name Started                
            break
        }
        else {
            Start-Sleep -Seconds 2	
        }	
    }
}

    # wait until customization process has started	
    Write-Host "Waiting for OS Customization to start ..."
    foreach ($WaitCustStart in $NewVMs) {
        while ($True) {
            $VmCustStartEvents = Get-VIEvent -Entity $WaitCustStart.Name
            $CustStartEvent = $VmCustStartEvents | Where-Object { $_.GetType().Name -eq "CustomizationStartedEvent" }
            if ($CustStartEvent) {
                write-host "OS Customisation in progress"
                break	
            }
            else {
                Start-Sleep -Seconds 2
            }
        }
    }

# wait until customization process has completed or failed
Write-Host "Waiting for customization to complete ..."
foreach ($WaitCustFinal in $NewVMs) {
    $WaitCustInProgress = $False
    while ($WaitCustInProgress -eq $False) {
        $VmCustFinalEvents = Get-VIEvent -Entity $WaitCustFinal.Name
        $SucceedEvent = $VmCustFinalEvents | Where-Object { $_.GetType().Name -eq "CustomizationSucceeded" }
        $FailEvent = $VmCustFinalEvents | Where-Object { $_.GetType().Name -eq "CustomizationFailed" }
        if ($failEvent) {
            Write-Host -ForegroundColor Red "Customization failed!"
            $WaitCustInProgress = $True
        }
        if ($succeedEvent) {
            Write-Host -ForegroundColor Green "Customization succeeded!"
            Remove-OSCustomizationSpec $VMCust.Hostname -Confirm: $false
            Write-Host $VMCust.Hostname "OS Profile removed"  
            $WaitCustInProgress = $True
        }
        else {
            Start-Sleep -Seconds 2			
        }
    }
}

# -- Close Connections --

foreach ($vm in $NewVMs) {
Write-Host -ForegroundColor Green "Script complete, closing connections."
$vmdescription = $vmdeploy.Description
wait-tools -vm $vmdeploy.Hostname -timeoutseconds 60
Get-VM -Name $vmdeploy.Hostname | Update-Tools -NoReboot
wait-tools -vm $vmdeploy.Hostname -timeoutseconds 60
$vmscript = @"
gpupdate /force
Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{description = '$vmdescription'}
write-host "Computer description now set to $vmdescription" 
"@
$script = Invoke-VMScript -VM $VMCust.Hostname -scripttype powershell -ScriptText $vmscript -GuestUser administrator -GuestPassword $localadminpwd.getnetworkcredential().password 
$script
write-host $script.ScriptOutput
$vmdescription = $vmdeploy.Description
$installwinupdate = Invoke-VMScript -vm $vmcust.Hostname -ScriptType PowerShell -ScriptText "Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot" -Guestuser administrator -guestpassword  $localadminpwd.getnetworkcredential().password
$installwinupdate
write-host $installwinupdate.ScriptOutput
Write-Output $installwinupdate.ScriptOutput >> C:\temp\windowsupdate.txt
Start-sleep -s 180
# -- check windows updates are installed
invoke-vmscript -vm $VMcust.Hostname -GuestUser administrator -GuestPassword $localadminpwd.GetNetworkCredential().Password -ScriptType Powershell -ScriptText Get-Hotfix
$adgroup = "DL_LA-" + $vmdeploy.Hostname
$vmscript = @"
Add-LocalGroupMember -Group "Administrators" -Member "BCA\$adgroup"
if((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain)
{write-host -foregroundcolor Green "server is joined to Domain"}
else
{write-host -foregroundcolor red "Server is not on a domain"}

if(Test-Connection -Quiet (Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Select-Object -ExpandProperty NextHop))

{write-host -foregroundColor Green "Gateway connectivity confirmed"}
 else 
{write-host -foregroundColor Red "Gateway connectivity failed please check network configuration"}
"@
$script = Invoke-VMScript -VM $VMCust.Hostname -scripttype powershell -ScriptText $vmscript -GuestUser administrator -GuestPassword $localadminpwd.getnetworkcredential().password 
$script
write-host $script.ScriptOutput
}