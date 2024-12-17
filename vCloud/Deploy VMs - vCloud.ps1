#Author: Richard Hilton
#Version: 1.0
#Purpose: Create vApps & VMs in vCloud directly from template and set hardware.
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Add Windows Server 2019 Support
#Adjustments Required:


# -- Script Variables; change for every deployment --

#Set variables; Deployment target
$vCloudAddress = "cloud.pulsant.com"
$CustomerAccountCode = "set me" # Example: "TEST"
$StartNewVMs = $true # Options: $true or $false
$DisableGuestCustomization = $true # Options: $true or $false
$RestartAfterDisableGuestCustomization = $true
$ChangeUUID = $false
$NewVMsDataInput = "Script" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = "$env:USERPROFILE\Documents\setme.csv"

#Set variables; VMs to deploy
<# Example:
Name,INST,Hostname,OrgVDC,vApp,OS,CPU,RAM,Network,IPAddress,PublicIPAddress,StoragePolicy,HDD1DiskFormat,HDD1Size,Username,Password
SRVR-00000001 (Server 1),INST-00000002,INST-00000002,<orgvdcname>,<vappname>,<os>,<cpus>,<ram>,<vcloudnetworkname>,<ipaddress>,<publicipaddress>,<storagepolicyname>,<Thin or Thick>,<hdd1size>,<username>,<password>
SRVR-00000003 (Server 2),INST-00000004,CustomHostname02,<orgvdcname>,<vappname>,<os>,<cpus>,<ram>,<vcloudnetworkname>,<ipaddress>,<publicipaddress>,<storagepolicyname>,<Thin or Thick>,<hdd1size>,<username>,<password>
#>

$NewVMsScriptInput = @'
Name,INST,Hostname,OrgVDC,vApp,OS,CPU,RAM,Network,IPAddress,PublicIPAddress,StoragePolicy,HDD1DiskFormat,HDD1Size,Username,Password

'@ | ConvertFrom-Csv


# -- Script Variables; change only if required --

#Set variables; Passwords
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"

#Set variables; Definitions
$TemplateCatalogs = @'
ProviderVDC,CatalogVDC
edi3clouc2
mkn1clouc2
rdg3clouc2
EDI3-CLOU-V01-Core
MKN1-CLOU-V01-Core
RDG3-CLOU-V01-Core
MKN1-C1-CL1
MKN1-C2-CL1
RDG3-C1-CL1
RDG3-C2-CL1
RDG3-C3-CL1
'@ | ConvertFrom-Csv

#Generate variables; Catalog Details
foreach ($TemplateCatalog in $TemplateCatalogs) {
    $TemplateCatalog.CatalogVDC = "PEC2 " + $TemplateCatalog.ProviderVDC + " VDC"
}

$Templates = @'
Name,Template,Type
Win2019,"201906-Win2019-STD-NSP",Windows
Win2016,"201802-Win2016-STD-NSP",Windows
Win2012R2,"201711-Win2012R2-STD-NSP",Windows
Win2008R2,"201801-Win2008R2-STD-NSP",Windows
CentOS7,"201802-CentOS7",Linux
Ubuntu1604,"201806-Ubuntu1604",Linux
'@ | ConvertFrom-Csv

$SaltMastersWindows = "europa.piiplat.com","sinope.piiplat.com","ananke.piiplat.com","kale.piiplat.com"
$SaltMastersLinux = "europa.piiplat.com","sinope.piiplat.com","ananke.piiplat.com","kale.piiplat.com"
# $SaltMastersLinux = "proteus.piiplat.com","halimede.piiplat.com"

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
if "%1%" == "precustomization" (
echo Do precustomization tasks
) else if "%1%" == "postcustomization" (
echo Do postcustomization tasks
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
    'Category'="OSUpdate"
    'Order'=700
    'OSes'=@("Win2019","Win2016")
    'Code'=@'
Powershell -EncodedCommand JABTAE0AIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHIAdgBpAGMAZQBNAGEAbgBhAGcAZQByADsAJABTAE0ALgBDAGwAaQBlAG4AdABBAHAAcABsAGkAYwBhAHQAaQBvAG4ASQBEACAAPQAgACIATQB5ACAAQQBwAHAAIgA7ACQAUwBNAC4AQQBkAGQAUwBlAHIAdgBpAGMAZQAyACgAIgA3ADkANwAxAGYAOQAxADgALQBhADgANAA3AC0ANAA0ADMAMAAtADkAMgA3ADkALQA0AGEANQAyAGQAMQBlAGYAZQAxADgAZAAiACwANwAsACIAIgApAA==
timeout 15
PowerShell -EncodedCommand JABVAFMAIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHMAcwBpAG8AbgA7ACQAVQBTAHIAIAA9ACAAJABVAFMALgBDAHIAZQBhAHQAZQBVAHAAZABhAHQAZQBTAGUAYQByAGMAaABlAHIAKAApADsAJABTAFIAIAA9ACAAJABVAFMAcgAuAFMAZQBhAHIAYwBoACgAIgBJAHMASQBuAHMAdABhAGwAbABlAGQAPQAwACAAYQBuAGQAIABUAHkAcABlAD0AJwBTAG8AZgB0AHcAYQByAGUAJwAiACkAOwAkAEQATAAgAD0AIAAkAFUAUwAuAEMAcgBlAGEAdABlAFUAcABkAGEAdABlAEQAbwB3AG4AbABvAGEAZABlAHIAKAApADsAJABEAEwALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQARABMAC4ARABvAHcAbgBsAG8AYQBkACgAKQA7ACQASQBOACAAPQAgACQAVQBTAC4AQwByAGUAYQB0AGUAVQBwAGQAYQB0AGUASQBuAHMAdABhAGwAbABlAHIAKAApADsAJABJAE4ALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQASQBOAC4ASQBuAHMAdABhAGwAbAAoACkA
'@
}

$GuestCustomizationScripts += @{
    'Category'="OSUpdate"
    'Order'=700
    'OSes'=@("Win2012R2","Win2008R2")
    'Code'=@'
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 3 /f
Powershell -EncodedCommand JABTAE0AIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHIAdgBpAGMAZQBNAGEAbgBhAGcAZQByADsAJABTAE0ALgBDAGwAaQBlAG4AdABBAHAAcABsAGkAYwBhAHQAaQBvAG4ASQBEACAAPQAgACIATQB5ACAAQQBwAHAAIgA7ACQAUwBNAC4AQQBkAGQAUwBlAHIAdgBpAGMAZQAyACgAIgA3ADkANwAxAGYAOQAxADgALQBhADgANAA3AC0ANAA0ADMAMAAtADkAMgA3ADkALQA0AGEANQAyAGQAMQBlAGYAZQAxADgAZAAiACwANwAsACIAIgApAA==
timeout 15
PowerShell -EncodedCommand JABVAFMAIAA9ACAATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AQwBvAG0ATwBiAGoAZQBjAHQAIABNAGkAYwByAG8AcwBvAGYAdAAuAFUAcABkAGEAdABlAC4AUwBlAHMAcwBpAG8AbgA7ACQAVQBTAHIAIAA9ACAAJABVAFMALgBDAHIAZQBhAHQAZQBVAHAAZABhAHQAZQBTAGUAYQByAGMAaABlAHIAKAApADsAJABTAFIAIAA9ACAAJABVAFMAcgAuAFMAZQBhAHIAYwBoACgAIgBJAHMASQBuAHMAdABhAGwAbABlAGQAPQAwACAAYQBuAGQAIABUAHkAcABlAD0AJwBTAG8AZgB0AHcAYQByAGUAJwAiACkAOwAkAEQATAAgAD0AIAAkAFUAUwAuAEMAcgBlAGEAdABlAFUAcABkAGEAdABlAEQAbwB3AG4AbABvAGEAZABlAHIAKAApADsAJABEAEwALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQARABMAC4ARABvAHcAbgBsAG8AYQBkACgAKQA7ACQASQBOACAAPQAgACQAVQBTAC4AQwByAGUAYQB0AGUAVQBwAGQAYQB0AGUASQBuAHMAdABhAGwAbABlAHIAKAApADsAJABJAE4ALgBVAHAAZABhAHQAZQBzACAAPQAgACQAUwBSAC4AVQBwAGQAYQB0AGUAcwA7ACQASQBOAC4ASQBuAHMAdABhAGwAbAAoACkA
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
    'Order'=800
    'OSes'=@("Win2019","Win2016","Win2012R2","Win2008R2")
    'Code'=@'
PowerShell -EncodedCommand KABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBOAGUAdAAuAFcAZQBiAGMAbABpAGUAbgB0ACkALgBEAG8AdwBuAGwAbwBhAGQARgBpAGwAZQAoACIAaAB0AHQAcAA6AC8ALwBkAG8AcgBpAHMALgBwAGkAaQBwAGwAYQB0AC4AYwBvAG0ALwBzAGEAbAB0AC8AcwBhAGwAdAAtAG0AaQBuAGkAbwBuAC4AZQB4AGUAIgAsACIAQwA6AFwAUAB1AGwAcwBhAG4AdABcAHMAYQBsAHQALQBtAGkAbgBpAG8AbgAuAGUAeABlACIAKQA=
C:\Pulsant\salt-minion.exe /S /master=windowssaltmaster.piiplat.com /minion-name=INST-00000000
erase C:\Pulsant\salt-minion.exe
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
    'Category'="Shutdown"
    'Order'=900
    'OSes'=@("Win2019","Win2016","Win2012R2","Win2008R2")
    'Code'=@'
shutdown /s /t 10
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
)
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

# $GuestCustomizationScripts | ForEach-Object { New-Object -TypeName psobject -Property $_ } | Format-Table Category,Order,OSes,Code -Wrap

# -- Open connections --

#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true

#Connect to vCloud
try {$vCloudConnection = Connect-CIServer -Server $vCloudAddress -Credential $vCloudCredential}
catch {throw}


# -- Verfication section --

Write-Host -ForegroundColor Green "Starting validation checks...`n"

# Initialize error counter
$Script:ErrorCount = 0

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

# Check Org exists
try {$VerificationOrgObject = Get-Org -Name $CustomerAccountCode}
catch {throw}

# Summarize OrgVDCs and RAM
$VerificationOrgVDCsRAM = $NewVMs | Group-Object "OrgVDC" | foreach {
    New-Object psobject -Property @{
        'OrgVDC' = ($_.Name -split ", ")[0]
        'RAM' = ($_.Group | Measure-Object 'RAM' -Sum).Sum
    }
}

# Check OrgVDCs exist and their RAM is sufficient
foreach ($VerificationOrgVDCRAM in $VerificationOrgVDCsRAM) {
    try {$VerificationOrgVDC = Get-OrgVdc -Org $VerificationOrgObject -Name $VerificationOrgVDCRAM.OrgVDC}
    catch {throw}
    if (($VerificationOrgVDC.MemoryAllocationGB - $VerificationOrgVDC.MemoryUsedGB) -lt $VerificationOrgVDCRAM.RAM) {
        $Script:ErrorCount ++ ; Write-Host -ForegroundColor Red $VerificationOrgVDC.Name does not have the required $VerificationOrgVDCRAM.RAM GB of RAM available.
    }
}

# Summarize OrgVDCs and Storage Policies
$VerificationStoragePolicies = $NewVMs | Group-Object "OrgVDC", "StoragePolicy" | foreach {
    New-Object psobject -Property @{
        'OrgVDC' = ($_.Name -split ", ")[0]
        'StoragePolicy' = ($_.Name -split ", ")[1]
        'Size' = ($_.Group | Measure-Object 'HDD1Size' -Sum).Sum + ($_.Group | Measure-Object 'RAM' -Sum).Sum
    }
}

# Check OrgVDC Storage Policies exist and are sufficient
foreach ($VerificationStoragePolicy in $VerificationStoragePolicies) {

    # Get Org VDC to Object, and get object ID
    $VerificationOrgVDC = Get-OrgVdc -Org $VerificationOrgObject -Name $VerificationOrgVDCRAM.OrgVDC ; $VerificationOrgVDCObjectID = $VerificationOrgVDC.ID

    # Get Storage policy name to explicit variable
    $VerificationStoragePolicyName = $VerificationStoragePolicy.StoragePolicy

    # Get Storage policy object
    $VerificationOrgVDCStoragePolicy = Search-Cloud -QueryType AdminOrgVdcStorageProfile -Filter "Vdc==$VerificationOrgVDCObjectID;Name==$VerificationStoragePolicyName" | Get-CiView

    # Check if storage policy exists
    if (!($VerificationOrgVDCStoragePolicy)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red $VerificationStoragePolicy.StoragePolicy storage policy not found in $VerificationStoragePolicy.OrgVDC Org VDC.}

    # If it does, check there is enough storage available via REST API
    else {
        $GetHeaders = @{ "x-vcloud-authorization" = [string]$VerificationOrgVDCStoragePolicy.Client.SessionKey ; "Accept" = "application/*+xml;version=20.0" }
        $VerificationOrgVDCStoragePolicyResponse = Invoke-WebRequest -Method Get -Uri $VerificationOrgVDCStoragePolicy.Href -Headers $GetHeaders
        [xml]$VerificationOrgVDCStoragePolicyResponseXML = $VerificationOrgVDCStoragePolicyResponse.Content
        if ((($VerificationOrgVDCStoragePolicyResponseXML.AdminVdcStorageProfile.Limit - $VerificationOrgVDCStoragePolicyResponseXML.AdminVdcStorageProfile.StorageUsedMB) / 1024) -lt $VerificationStoragePolicy.Size) {
            $Script:ErrorCount ++ ; Write-Host -ForegroundColor Red $VerificationStoragePolicy.OrgVDC / $VerificationStoragePolicy.StoragePolicy does not have the required $VerificationStoragePolicy.Size GB of storage available.
        }
    }
}

# Summarize Org VDCs and vApps
$VerificationvApps = $NewVMs | Group-Object "OrgVDC", "vApp" | foreach {
    New-Object psobject -Property @{
        'OrgVDC' = ($_.Name -split ", ")[0]
        'vApp' = ($_.Name -split ", ")[1]
    }
}

# Check if vApps exist in Org VDCs
foreach ($VerificationvApp in $VerificationvApps) {
    # Get Org VDC to Object
    $VerificationOrgVDC = Get-OrgVdc -Org $VerificationOrgObject -Name $VerificationvApp.OrgVDC
    # Check if vApp exists in Org VDC
    if (!(Get-CIVApp -Org $VerificationOrgObject -OrgVdc $VerificationOrgVDC -Name $VerificationvApp.vApp)) {
        $Script:ErrorCount ++ ; Write-Host -ForegroundColor Red $VerificationvApp.vApp vApp not found in $VerificationvApp.OrgVDC Org VDC.
    }
}

# Summarize Org VDCs, vApps, and Networks
$VerificationvAppsNetworks = $NewVMs | Group-Object "OrgVDC", "vApp", "Network" | foreach {
    New-Object psobject -Property @{
        'OrgVDC' = ($_.Name -split ", ")[0]
        'vApp' = ($_.Name -split ", ")[1]
        'Network' = ($_.Name -split ", ")[2]
    }
}

# Check if Networks exist in vApps in Org VDCs
foreach ($VerificationvAppNetwork in $VerificationvAppsNetworks) {
    # Get Org VDC to Object
    $VerificationOrgVDC = Get-OrgVdc -Org $VerificationOrgObject -Name $VerificationvAppNetwork.OrgVDC
    # Try to get vApp to object and check if it exists in Org VDC
    $VerificationvAppNetworkvApp = Get-CIVApp -Org $VerificationOrgObject -OrgVdc $VerificationvAppNetwork.OrgVDC -Name $VerificationvAppNetwork.vApp -ErrorAction SilentlyContinue
    if ($VerificationvAppNetworkvApp) {
        if (!(Get-CIVAppNetwork -VApp $VerificationvAppNetworkvApp -Name $VerificationvAppNetwork.Network -ErrorAction SilentlyContinue)) {
            $Script:ErrorCount ++ ; Write-Host -ForegroundColor Red $VerificationvAppNetwork.OrgVDC / $VerificationvAppNetwork.vApp is missing the $VerificationvAppNetwork.Network network.
        }
    }
}

# Check VM Details

# Check for duplicate IPs in new VM list
if ($NewVMs.IPAddress | Group-Object | Where-Object -Property Count -GT 1) {
    $Script:ErrorCount ++ ; $NewVMs.IPAddress | Group-Object | Where-Object -Property Count -GT 1 | foreach {Write-Host -Foreground Red $_.Name is repeated $_.Count times}
}


Foreach ($NewVM in $NewVMs) {

    # Check if VM exists already
    if (Get-CIVM -Org $VerificationOrgObject -Name $NewVM.Name -ErrorAction SilentlyContinue) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name VM already exists}

    # Check INST code looks correct
    if (!($NewVM.INST -match 'INST-[0-9A-F]{8}')) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name INST code of $NewVM.INST does not look like an INST code.}

    # Check VM hostname length
    if ($NewVM.Hostname.Length -ge 15 -or $NewVM.Hostname.Length -le 0) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name hostname of $NewVM.Hostname is not between 1 and 15 characters.}

    # Check if CPU & RAM are sensible numbers
    if (!([int]::TryParse($NewVM.CPU,[ref]1) -and ($NewVM.CPU -as [int]) -ge 1 -and ($NewVM.CPU -as [int]) -le 8)) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name CPU is not an integer between 1 and 8}
    if (!([decimal]::TryParse($NewVM.RAM,[ref]1) -and $NewVM.RAM -as [decimal] -ge 1 -and $NewVM.RAM -as [decimal] -le 56)) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name RAM is not an integer between 1 and 56}

    # Check if OS is supported by script
    if (!($Templates.Name -contains $NewVM.OS)) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name OS $NewVM.OS is not currently supported by this script}

    # Check if Guest Customization script exists for OS
    if (!($GuestCustomizationScripts.OSes -contains $NewVM.OS)) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name OS $NewVM.OS does not currently have a guest customization script in this script}

    # Check if IP address is an IP address
    if (!([bool]($NewVM.IPAddress -as [ipaddress]))) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name IP Address is invalid}

    # Check if IP address matches network specification
    $VerificationvAppNetwork = Get-OrgVdcNetwork -OrgVdc $NewVM.OrgVDC -Name $NewVM.Network
    if (!((([Net.IPAddress]$VerificationvAppNetwork.DefaultGateway).Address -band ([Net.IPAddress]$VerificationvAppNetwork.Netmask).Address) -eq (([Net.IPAddress]$NewVM.IPAddress).Address -band ([Net.IPAddress]$VerificationvAppNetwork.Netmask).Address))) {
        $Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name IP address $NewVM.IPAddress is not in the same subnet as gateway $VerificationvAppNetwork.DefaultGateway with mask $VerificationvAppNetwork.Netmask
    }

    # Check if HDD1Size is a sensible number
    if (!([int]::TryParse($NewVM.HDD1Size,[ref]1) -and ($NewVM.HDD1Size -as [int]) -ge 1)) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name HDD1Size is not an integer greater than or equal to 1}

    # Check if HDD1Format is Thick or Thin
    if (!($NewVM.HDD1DiskFormat -match "Thin" -or $NewVM.HDD1DiskFormat -match "Thick")) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name HDD1Format is neither Thin nor Thick}

    # Check that password is at least 8 characters long
    if (!($NewVM.Password.Length -ge 8)) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name Password is less than 8 characters long}

        # Check password complexity - match 3 out of 4 of Uppercase, Lowercase, Number, and Symbols # ! $ % @
        if (!($NewVM.Password -match "(?=.+[A-Z])(?=.+[a-z])(?=.+\d)" -or $NewVM.Password -match "(?=.+[a-z])(?=.+\d)(?=.+[^A-Za-z0-9])" -or $NewVM.Password -match "(?=.+[A-Z])(?=.+\d)(?=.+[^A-Za-z0-9])" -or $NewVM.Password -match "(?=.+[A-Z])(?=.+[a-z])(?=.+[^A-Za-z0-9])")) {
            $Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name Password is not complex enough: Requires 3 out of 4 Uppercase, Lowercase, Number, and Symbol
        }

    # Check that template exists
    $VerificationVMProviderVDC = ((Get-OrgVdc $NewVM.OrgVDC).ProviderVdc).Name
    foreach ($Template in $Templates) {
        if ($Template.Name -match $NewVM.OS) {$VerificationVMTemplateName = $Template.Template}
    }
    $VMTemplates = Get-CIVMTemplate -Name $VerificationVMTemplateName

    foreach ($TemplateCatalog in $TemplateCatalogs) {
        if ($TemplateCatalog.ProviderVDC -match $VerificationVMProviderVDC) {$VerificationVMTemplateCatalogVDC = $TemplateCatalog.CatalogVDC}
    }

    foreach ($VMTemplate in $VMTemplates) {
        if ($VMTemplate.OrgVdc.Name -ilike $VerificationVMTemplateCatalogVDC) {$VerificationVMTemplate = $VMTemplate}
    }

    if (!($VerificationVMTemplate)) {$Script:ErrorCount ++ ; Write-Host -Foreground Red $VerificationVMTemplateName template for $NewVM.Name could not be found.}
}

# Check script has vCenter access if it needs it
if ($ChangeUUID) { if (!($env:USERDOMAIN -eq "PIIPLAT")) {$Script:ErrorCount ++ ; Write-Host -Foreground Red Script does not appear to have vCenter access - executed from $env:USERDOMAIN domain.} }


# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification.`nExiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding to deploy VMs.`n" }


# -- Script actions start here --

# Create New VMs
Foreach ($NewVM in $NewVMs) {

    Write-Host -ForegroundColor Green Starting deployment of $NewVM.Name

    # Get Provider VDC to Object
    $NewVMProviderVDC = ((Get-OrgVdc $NewVM.OrgVDC).ProviderVdc).Name

    # Work out which template to use
    foreach ($Template in $Templates) {
        if ($Template.Name -match $NewVM.OS) {$NewVMTemplateOS = $Template}
    }
    $VMTemplates = Get-CIVMTemplate -Name $NewVMTemplateOS.Template

    foreach ($TemplateCatalog in $TemplateCatalogs) {
        if ($TemplateCatalog.ProviderVDC -match $NewVMProviderVDC) {$NewVMTemplateCatalogVDC = $TemplateCatalog.CatalogVDC}
    }

    foreach ($VMTemplate in $VMTemplates) {
        if ($VMTemplate.OrgVdc.Name -ilike $NewVMTemplateCatalogVDC) {$NewVMTemplate = $VMTemplate}
    }

    # Get Org & Org VDC objects & ID
    $NewVMOrg = Get-Org -Name $CustomerAccountCode
    $NewVMOrgVDCObject = Get-OrgVdc -Org $NewVMOrg -Name $NewVM.OrgVDC
    $NewVMOrgVDCObjectID = $NewVMOrgVDCObject.ID

    # Take copy of existing storage policy configuration
    $OrgVdcStoragePoliciesOriginal = Search-Cloud -QueryType AdminOrgVdcStorageProfile -Filter "Vdc==$NewVMOrgVDCObjectID" | Get-CiView
    $OrgVdcStoragePolicies = Search-Cloud -QueryType AdminOrgVdcStorageProfile -Filter "Vdc==$NewVMOrgVDCObjectID" | Get-CiView
    # $OrgVdcStoragePolicies = $OrgVdcStoragePoliciesOriginal

    # Temporarily adjust default storage policy
    Write-Host -ForegroundColor DarkGreen Temporarily adjusting storage policies...
    $NewVMStoragePolicyName = $NewVM.StoragePolicy
    $NewVMStoragePolicy = Search-Cloud -QueryType AdminOrgVdcStorageProfile -Filter "Vdc==$NewVMOrgVDCObjectID;Name==$NewVMStoragePolicyName" | Get-CiView
    $NewVMStoragePolicy.Default = $true
    $NewVMStoragePolicy.Enabled = $true
    $null = $NewVMStoragePolicy.UpdateServerData()

    # Temporarily disable other storage policies
    foreach ($OrgVdcStoragePolicy in $OrgVdcStoragePolicies) {
        if ($OrgVdcStoragePolicy.Id -ne $NewVMStoragePolicy.Id -and $OrgVdcStoragePolicy.Enabled -eq $true) {
            $OrgVdcStoragePolicy.Default = $false
            $OrgVdcStoragePolicy.Enabled = $false
            $null = $OrgVdcStoragePolicy.UpdateServerData()
        }
    }

    # Get vApp object for the new VM
    $NewVMvAppObject = $NewVMOrgVDCObject | Get-CIVApp -Name $NewVM.vApp

    # Deploy the new VM
    $NewVMObject = New-CIVM -VApp $NewVMvAppObject -VMTemplate $NewVMTemplate -Name $NewVM.Name -ComputerName $NewVM.Hostname

    # Restore default storage policy
    foreach ($OrgVdcStoragePolicy in $OrgVdcStoragePoliciesOriginal) {
        if ($OrgVdcStoragePolicy.Default -eq $true) { $null = $OrgVdcStoragePolicy.UpdateServerData() }
    }

    # Restore other storage policies
    foreach ($OrgVdcStoragePolicy in $OrgVdcStoragePoliciesOriginal) {
        if ($OrgVdcStoragePolicy.Default -eq $false) { $null = $OrgVdcStoragePolicy.UpdateServerData() }
    }
    Write-Host -ForegroundColor DarkGreen Storage policies restored

    # Get VirtualHardware Object
    $NewVMObjectView = $NewVMObject | Get-CIView
    $NewVMVirtualHardwareObject = $NewVMObjectView.GetVirtualHardwareSection()

    # Set CPU
    $NewVMObject.ExtensionData.Section[0].Item[5].VirtualQuantity.Value = $NewVM.CPU
    $NewVMObject.ExtensionData.Section[0].Item[5].ElementName.Value = $NewVM.CPU + " virtual CPU(s)"

    # Set RAM
    if ($NewVMObject.ExtensionData.Section[0].Item[6].AllocationUnits.Value -eq "byte * 2^20") {
        $NewVMObject.ExtensionData.Section[0].Item[6].VirtualQuantity.Value = [UInt64]$NewVM.RAM * 1024
    }

    # Write Section 0 changes to vCloud
    $NewVMObject.ExtensionData.Section[0].UpdateServerData()

    # Connect Network Adapter
    $NewVMObject.ExtensionData.Section[2].NetworkConnection[0].Network = $NewVM.Network
    $NewVMObject.ExtensionData.Section[2].NetworkConnection[0].IsConnected = $true
    if ($NewVM.IPAddress -ieq "Pool") {
        $NewVMObject.ExtensionData.Section[2].NetworkConnection[0].IpAddressAllocationMode = "POOL"
    }
    Else {
        $NewVMObject.ExtensionData.Section[2].NetworkConnection[0].IpAddressAllocationMode = "MANUAL"
        $NewVMObject.ExtensionData.Section[2].NetworkConnection[0].IpAddress = $NewVM.IPAddress
    }

    # Write Section 2 changes to vCloud
    $NewVMObject.ExtensionData.Section[2].UpdateServerData()

    
    # Enable Guest Customization
    $NewVMObject.ExtensionData.Section[3].Enabled = $true
    $NewVMObject.ExtensionData.Section[3].ChangeSid = $true

    # Set Password & auto login for Guest Customisation
    $NewVMObject.ExtensionData.Section[3].AdminPasswordAuto = $false
    $NewVMObject.ExtensionData.Section[3].AdminPassword = $NewVM.Password
    $NewVMObject.ExtensionData.Section[3].AdminAutoLogonEnabled = $true
    $NewVMObject.ExtensionData.Section[3].AdminAutoLogonCount = 1

    # Set Guest Customization Scripts
    switch ($NewVMTemplateOS.Type) { Windows {$CommentCharacter = "::" ; $NewVMGuestCustomizationScript = ""} Linux {$CommentCharacter = "#" ; $NewVMGuestCustomizationScript = "#!/bin/bash`n"} }
    $NewVMGuestCustomizationScriptModules = $GuestCustomizationScripts | Where-Object { $_.OSes -contains $NewVM.OS } | Sort-Object -Property "Order"
    foreach ($NewVMGuestCustomizationScriptModule in $NewVMGuestCustomizationScriptModules) {
        $NewVMGuestCustomizationScript += "`n" + $CommentCharacter + " " + $NewVMGuestCustomizationScriptModule.Category + " " + $NewVMGuestCustomizationScriptModule.Order + "`n"
        $NewVMGuestCustomizationScript += $NewVMGuestCustomizationScriptModule.Code + "`n"
    }
    
    $NewVMGuestCustomizationScript = $NewVMGuestCustomizationScript `
        -replace "windowssaltmaster.piiplat.com", (Get-Random -InputObject $SaltMastersWindows) `
        -replace "linuxsaltmaster.piiplat.com", (Get-Random -InputObject $SaltMastersLinux) `
        -replace "INST-00000000", $NewVM.INST

    $NewVMObject.ExtensionData.Section[3].CustomizationScript = $NewVMGuestCustomizationScript

    # Write Section 3 changes to vCloud
    $NewVMObject.ExtensionData.Section[3].UpdateServerData()


    # Extend HDD1
      # Get VM Controllers & Hard Disks
    $NewVMDisks = $NewVMVirtualHardwareObject.GetDisks()

      # Set headers for Get operation
    $GetHeaders = @{
        "x-vcloud-authorization" = [string]$NewVMDisks.Client.SessionKey
        "Accept" = "application/*+xml;version=20.0"
    }

      # Get VM Controllers & Hard Disks from Web API
    $NewVMDisksGetResponse = Invoke-WebRequest -Method Get -Uri $NewVMDisks.Href -Headers $GetHeaders
    [xml]$NewVMDisksGetResponseXML = $NewVMDisksGetResponse.Content

      # Update capacity
    $NewVMDisksGetResponseXML.RasdItemsList.Item[1].HostResource.capacity = [string]([UInt64]$NewVM.HDD1Size * 1024)
    #$PutBody = $NewVMDisksGetResponseXML.InnerXml

      # Set headers for Put operation
    $PutHeaders = @{
        "x-vcloud-authorization" = [string]$NewVMDisks.Client.SessionKey
        "Accept" = "application/*+xml;version=1.5"
        "Content-Type" = "application/vnd.vmware.vcloud.rasditemslist+xml"
    }

      # Apply disk size changes
    $NewVMDisksPutResponse = Invoke-WebRequest -Method Put -Uri $NewVMDisks.Href -Headers $PutHeaders -Body $NewVMDisksGetResponseXML.InnerXml

      # Wait for disk size change to complete
    do {
        Start-Sleep -Seconds 5
        $NewVMDisksExpandTaskResponse = Invoke-WebRequest -Method Get -Uri $NewVMDisksPutResponse.Headers.Location -Headers $GetHeaders
        [xml]$NewVMDisksExpandTaskResponseXML = $NewVMDisksExpandTaskResponse.Content
        if ($NewVMDisksExpandTaskResponseXML.Task.Status -match "queued" -or $NewVMDisksExpandTaskResponseXML.Task.Status -match "preRunning" -or $NewVMDisksExpandTaskResponseXML.Task.Status -match "running") {
            Write-Host -ForegroundColor DarkGreen HDD1 Expand task status is: $NewVMDisksExpandTaskResponseXML.Task.Status
        } elseif ($NewVMDisksExpandTaskResponseXML.Task.Status -match "success") {
            Write-Host -ForegroundColor DarkGreen HDD1 Expand task status is: $NewVMDisksExpandTaskResponseXML.Task.Status
        } else { Write-Host -ForegroundColor Red HDD1 Expand task status is: $NewVMDisksExpandTaskResponseXML.Task.Status }
    }
    while ($NewVMDisksExpandTaskResponseXML.Task.Status -match "queued" -or $NewVMDisksExpandTaskResponseXML.Task.Status -match "preRunning" -or $NewVMDisksExpandTaskResponseXML.Task.Status -match "running")

      # Upgrade hardware version to latest available
    $NewVMObject.ExtensionData.UpgradeHardwareVersion()

    # Start new VMs if set to do so
    if ($StartNewVMs -eq $true) {
        Write-Host -ForegroundColor DarkGreen Starting VM...
        $NewVMPowerStatus = Start-CIVM -VM $NewVMObject
        if ($NewVMPowerStatus.Status -match "PoweredOn") { Write-Host -ForegroundColor DarkGreen VM status is: $NewVMPowerStatus.Status }
        else { Write-Host -ForegroundColor Red VM status is: $NewVMPowerStatus.Status }
    }

    Write-Host -ForegroundColor Green Finished deployment of $NewVM.Name`n
}

# Disable Guest Customization if set to do so

if ($DisableGuestCustomization -eq $true) {
    Foreach ($NewVM in $NewVMs) {
        
        $NewVMObject = Get-CIVM -Org $CustomerAccountCode -OrgVdc $NewVM.OrgVDC -VApp $NewVM.vApp -Name $NewVM.Name
        while ($NewVMObject.Status -notlike "PoweredOff") { Write-Host -ForegroundColor Yellow Waiting for $NewVM.Name to complete Guest Customization script...; Start-Sleep -Seconds 60; $NewVMObject = Get-CIVM $NewVMObject}
        Write-Host -ForegroundColor Green $NewVM.Name has completed Guest Customization script.`nProceeding to disable Guest Customization...
        $null = Stop-CIVM -VM $NewVMObject -Confirm:$false
        
        $NewVMObject = Get-CIVM $NewVMObject
        
        if ($NewVMObject.Status -eq "PoweredOff" ) {

            # Clear Guest Customization settings
            $NewVMObject.ExtensionData.Section[3].CustomizationScript = $null
            $NewVMObject.ExtensionData.Section[3].AdminPassword = $null
            $NewVMObject.ExtensionData.Section[3].AdminAutoLogonEnabled = $false
            $NewVMObject.ExtensionData.Section[3].AdminAutoLogonCount = $null
            $NewVMObject.ExtensionData.Section[3].AdminPassword = $false
            $NewVMObject.ExtensionData.Section[3].ChangeSid = $false

            # Disable Guest Customization
            $NewVMObject.ExtensionData.Section[3].Enabled = $false

            # Write Section 3 changes to vCloud
            $NewVMObject.ExtensionData.Section[3].UpdateServerData()

                        # Change BIOS UUID if set to do so
                        if ($ChangeUUID) {
                            $null = Connect-VIServer $NewVMObject.OrgVdc.ProviderVdc.ExtensionData.VimServer.Name
                            $NewVMObjectVI = Get-ResourcePool -Name ($NewVMObject.OrgVdc.Name + " (" + ($NewVMObject.OrgVdc.Id -split ":")[-1] + ")") | Get-VM -Name ($NewVMObject.Name + " (" + ($NewVMObject.Id -split ":")[-1] + ")")
                            $NewUuid = "{0:x8}" -f (Get-Random 4294967295) + "{0:x8}" -f (Get-Random 4294967295) + "{0:x8}" -f (Get-Random 4294967295) + "{0:x8}" -f (Get-Random 4294967295)
                            $VMConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
                            $VMConfigSpec.Uuid = $NewUuid
                            $NewVMObjectVI.Extensiondata.ReconfigVM($VMConfigSpec)
                            $null = Disconnect-VIServer $NewVMObject.OrgVdc.ProviderVdc.ExtensionData.VimServer.Name -Confirm:$false
                        }
        } else {

            Write-Host -ForegroundColor Red $NewVM.Name did not shut down, aborting...
            return
        }
        if ($RestartAfterDisableGuestCustomization) { $null = Start-CIVM -VM $NewVMObject }
    }
}

# -- Close Connections --
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-CIServer -Server $vCloudAddress -Confirm:$false
Remove-Variable vCloudCredential
Remove-Variable vCloudConnection
