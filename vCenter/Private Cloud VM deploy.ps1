#Author: Paul Brazier
#Version: 1.8
#Purpose: Private Cloud VM deploy
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by: Richard Hilton
#Status: Ready for testing
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Add Windows Server 2019 Support
#Adjustments Required: 

# -- Script Variables; change for every deployment --
$vCenterAddress = 'set me'
$NewVMsDataInput = "Script" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = "$env:USERPROFILE\Documents\setme.csv"

$StartVMs = $true

$ArmorInstallString = 'set me'
#Set variables; VMs to deploy
<#Example
Template,Name,Folder,ResourcePool,Datastore,CPU,RAM,HDD1Size,Network,IPMode,IPAddress,Subnet,Gateway,DNS1,DNS2,Password
201711-Win2012R2-STD-NSP,PB-TEST-2012,PB VMs,PB VMs,PROV-VMFS1 (15K SAS),2,8,80,PB Network - VLAN102,UseStaticIP,172.22.102.180,255.255.255.0,172.22.102.1,89.151.64.70,81.29.64.60,MyPassword35
201802-Win2016-STD-NSP,PB-TEST-2016,PB VMs,PB VMs,PROV-VMFS1 (15K SAS),2,8,100,PB Network - VLAN102,UseStaticIP,172.22.102.181,255.255.255.0,172.22.102.1,89.151.64.70,81.29.64.60,MyPassword35
#>
$NewVMsScriptInput = @'
Template,Name,Folder,ResourcePool,Datastore,CPU,RAM,HDD1Size,Network,IPMode,IPAddress,Subnet,Gateway,DNS1,DNS2,Password
'@ | ConvertFrom-Csv

# -- Script Variables; change only if required --
#Set variables; Passwords
#$vCenterCredential = Get-Credential -Message 'Enter your vCenter Credentials'
#$VMCredential = Get-Credential -Message 'Enter your Virtual Machine Credentials'

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
echo select disk 0 >C:\Pulsant\extend.txt
echo select partition 2 >>C:\Pulsant\extend.txt
echo extend >>C:\Pulsant\extend.txt
diskpart /s C:\Pulsant\extend.txt
erase C:\Pulsant\extend.txt
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
    'Category'="CDP"
    'Order'=400
    'OSes'=@("CentOS7")
    'Code'=@'
yum remove serverbackup-* -y
'@
}

$GuestCustomizationScripts += @{
    'Category'="SaltInstall"
    'Order'=700
    'OSes'=@("CentOS7","Ubuntu1604")
    'Code'=@'
export SALT_DIR=$(mktemp -d)
wget -q http://doris.piiplat.com/salt/server-seasoning.sh -O ${SALT_DIR}/server-seasoning.sh
bash ${SALT_DIR}/server-seasoning.sh -l -m linuxsaltmaster.piiplat.com -i INST-00000000
'@
}

$GuestCustomizationScripts += @{
    'Category'="SaltInstall"
    'Order'=700
    'OSes'=@("Win2019","Win2016","Win2012R2","Win2008R2")
    'Code'=@'
PowerShell -EncodedCommand KABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBOAGUAdAAuAFcAZQBiAGMAbABpAGUAbgB0ACkALgBEAG8AdwBuAGwAbwBhAGQARgBpAGwAZQAoACIAaAB0AHQAcAA6AC8ALwBkAG8AcgBpAHMALgBwAGkAaQBwAGwAYQB0AC4AYwBvAG0ALwBzAGEAbAB0AC8AcwBhAGwAdAAtAG0AaQBuAGkAbwBuAC4AZQB4AGUAIgAsACIAQwA6AFwAUAB1AGwAcwBhAG4AdABcAHMAYQBsAHQALQBtAGkAbgBpAG8AbgAuAGUAeABlACIAKQA=
C:\Pulsant\salt-minion.exe /S /master=windowssaltmaster.piiplat.com /minion-name=INST-00000000
erase C:\Pulsant\salt-minion.exe
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
    'Category'="ClearHistory"
    'Order'=850
    'OSes'=@("CentOS7","Ubuntu1604")
    'Code'=@'
rm -rf /root/pulsant/* && ls /root/pulsant && cat /dev/null > ~/.bash_history && history -c
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
    'OSes'=@("Win2019","Win2016","Win2012R2","Win2008R2")
    'Code'=@'
rd C:\Users\Public\Desktop\PostInstallRunning
md C:\Pulsant\PostInstallFinished
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

$SaltMastersWindows = "europa.piiplat.com","sinope.piiplat.com","ananke.piiplat.com","kale.piiplat.com"
$SaltMastersLinux = "europa.piiplat.com","sinope.piiplat.com","ananke.piiplat.com","kale.piiplat.com"



# -- Open connections --
#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true
#Connect to vCenter
if (!$vCenterConnection) { $vCenterConnection = Connect-VIServer -Server $vCenterAddress -Force -ErrorAction Stop }
elseif ($vCenterConnection.IsConnected -ne $true) { $vCenterConnection = Connect-VIServer -Server $vCenterAddress -Force -ErrorAction Stop }


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
    $DoesVmExist = get-vm -Name $VmExist.Name -ErrorAction 'SilentlyContinue'
    if ($DoesVmExist) {
        Write-Host -ForegroundColor Red $VmExist.Name "already exists!"
        Throw
    }
}

#Ensure existing matching profiles are removed so new customisation data is used

Write-Host "Checking if OS Profiles already exist and removing"
foreach ($VmCustRemove in $NewVMs) {
    $OsProfileExist = Get-OSCustomizationSpec $VmCustRemove.Name -ErrorAction 'SilentlyContinue'
    if ($OsProfileExist) {
        Remove-OSCustomizationSpec $VmCustRemove.Name -Confirm: $false
        Write-Host $VmCustRemove.Name "OS Profiles removed"     
    }
}

#Generate new OS customisation profiles
Write-Host "Creating OS customisation profile..."
foreach ($VMCust in $NewVMs) {
    $VMCustSpec = New-OSCustomizationSpec -Name $VMCust.Name -FullName 'Support' -OrgName 'Pulsant' -OSType Windows -ChangeSid -Workgroup 'WORKGROUP' -AdminPassword $VMCust.Password -TimeZone 085 -AutoLogonCount 1 -NamingPrefix $VMCust.Hostname -NamingScheme fixed
    switch ($VMCust.IPMode) {
        UseStaticIP { $VMCustSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -Position '1' -IpMode $VMCust.IPMode -IpAddress $VMCust.IPAddress -SubnetMask $VMCust.Subnet -DefaultGateway $VMCust.Gateway -Dns $VMCust.DNS1, $VMCust.DNS2 }
        UseDhcp { $VMCustSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -Position '1' -IpMode $VMCust.IPMode }
    }
    if ($VMCust.DomainJoin -like "Yes") {
        $VMCustSpec | Set-OSCustomizationSpec -Domain $VMCust.DomainName -DomainUsername $VMCust.DomainUsername -DomainPassword $VMCust.DomainPassword
    }

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
        -replace "windowssaltmaster.piiplat.com", (Get-Random -InputObject $SaltMastersWindows) `
        -replace "linuxsaltmaster.piiplat.com", (Get-Random -InputObject $SaltMastersLinux) `
        -replace "INST-00000000", $VMCust.INST `
        -replace "<AdditionalDisks>", $NewDiskGuestCustomizationScript `
        -replace "<InstallAV>", $AvGuestCustomizationScript
    
    if ($NewVMGuestCustomizationScript) {
        #$NewVMGuestCustomizationArray = $NewVMGuestCustomizationScript -split "`n" | Where-Object {$_ -ne ""} | Where-Object {$_ -notlike "*::*"}
        #$NewVMGuestCustomizationArray = $NewVMGuestCustomizationArray | % { "echo " + $_ + " >> C:\Pulsant\GC.bat" }
        #$NewVMGuestCustomizationArray += "timeout 10 & C:\Pulsant\GC.bat"
        #$VMCustSpec | Set-OSCustomizationSpec -GuiRunOnce ( $NewVMGuestCustomizationArray)
        #$NewVMGuestCustomizationArray = $NewVMGuestCustomizationScript -split "`n" | Where-Object {$_ -ne ""} | Where-Object {$_ -notlike "*::*"}
        #$VMCustSpec | Set-OSCustomizationSpec -GuiRunOnce ( $NewVMGuestCustomizationArray)
        #$NewVMGuestCustomizationArray = $NewVMGuestCustomizationScript -split "`n" | Where-Object {$_ -ne ""} | Where-Object {$_ -notlike "*::*"}
        #[string]$NewVMGuestCustomizationString = 'cmd /c "' + ($NewVMGuestCustomizationArray -join " & ") + '"'
        #$VMCustSpec | Set-OSCustomizationSpec -GuiRunOnce ( $NewVMGuestCustomizationString )
        $NewVMGuestCustomizationArray = $NewVMGuestCustomizationScript -split "`r" -split "`n" | Where-Object {$_ -ne ""}
        $NewVMGuestCustomizationArrayWrapped = @()
        foreach ($Item in $NewVMGuestCustomizationArray) {
            [string]$Prefix = 'cmd /c "echo '
            [string]$Suffix = '>> C:\Pulsant\Customization.bat"'
            [string]$Item = $Prefix + $Item + $Suffix
            while ($Item.Length -ge 250) {
                [string]$SubItem = $Item.Substring(0,(250 - 2 - $Suffix.Length)) + "^^" + $Suffix
                $NewVMGuestCustomizationArrayWrapped += $SubItem
                [string]$Item = $Prefix + $Item.Substring(250 - 2 - $Suffix.Length)
            }
            $NewVMGuestCustomizationArrayWrapped += $Item
        }
        $NewVMGuestCustomizationArrayWrapped += 'cmd /c "C:\Pulsant\Customization.bat"'
        $NewVMGuestCustomizationArrayWrapped += 'cmd /c "erase C:\Pulsant\Customization.bat"'
        $VMCustSpec | Set-OSCustomizationSpec -GuiRunOnce ( $NewVMGuestCustomizationArrayWrapped )
    }
}

Start-Sleep -Seconds 5

# Deploy New VMs and set resources
Write-Host "Deploying VMs..."
foreach ($VMDeploy in $NewVMs) {
    $VMDeployObject = New-VM -Name $VMDeploy.Name -Template $VMDeploy.Template -OSCustomizationSpec $VMDeploy.Name -Datastore $VMDeploy.Datastore -Location $VMDeploy.Folder -ResourcePool $VMDeploy.ResourcePool -DiskStorageFormat $VMDeploy.HDD1DiskFormat
    #$VMDeployObject = Get-VM $VMDeploy.Name
    $VMDeployObject | Set-VM -MemoryGB $VMDeploy.RAM -NumCpu $VMDeploy.CPU -Confirm: $false
    $VMDeployObject | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $VMDeploy.Network -Confirm: $false
    Get-HardDisk -VM $VMDeployObject | Where-Object {$_.Name -eq "hard disk 1"} | Set-HardDisk -CapacityGB $VMDeploy.HDD1Size -Confirm:$false
    if ($VMDeploy.HDDAdditional) {
        foreach ($NewDisk in $VMDeploy.HDDAdditional -split ";") {
            $NewDiskProperties = $NewDisk -split ","
            New-HardDisk -VM $VMDeployObject -CapacityGB $NewDiskProperties[0] -StorageFormat $NewDiskProperties[1]
        }
    }
    if ($StartVMs -eq $true) { Start-VM $VMDeploy.Name -Confirm:$False -ErrorAction:Stop }
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
            Remove-OSCustomizationSpec $WaitCustFinal.Name -Confirm: $false
            Write-Host $WaitCustFinal.Name "OS Profile removed"  
            $WaitCustInProgress = $True
        }
        else {
            Start-Sleep -Seconds 2			
        }
    }
}

# -- Close Connections --
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-VIServer -Server $vCenterAddress -Confirm:$True
#Remove-Variable vCenterCredential