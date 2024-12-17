## Author: James White
## Version: 0.1
## Creation date: 06/10/2020 
## Purpose: Install SQL Server following deployment standards
## Dependencies: PowerShell Version 4 or higher
## Prequisities: You must have created a VM with 2 spares disks attached

# Last Change by: James White
# Status: New
# Recommended Run Mode: PowerShell prompt
# Changes: Initial build
# Adjustments Required: 

<#
.SYNOPSIS
New-SQLServer Installs SQL Server following Pulsant deployment standards
.DESCRIPTION 
New-SQLServer installs SQL Server using a hardcoded cofiguration file which has been customised to our requirements. 
.PARAMETER isoLocation
The path to the SQL ISO file which you want to install
.PARAMETER pathToConfigurationFile
The path to the SQL ini configuration file specific to the version which you want to install
.PARAMETER sapwd
The SA password generated in MIST
.EXAMPLE
.\New-SQLServer.ps1 -isoLocation "\\shared.dedipower.com\Provisioning\ISOs\Microsoft\SPLA\SQL Server\2019\SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2019Dec2019_64Bit_English_OEM_VL_X22-22109.ISO" -pathToConfigurationFile "\\shared.dedipower.com\Provisioning\James W\ConfigurationFileSimonW.ini" -sapwd "cPp52JK&VgzAgEG"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Enter the path to the ISO file")]
    [string]$isoLocation,
    [Parameter(Mandatory=$True,HelpMessage="Enter the path to the configuration file")]
    [string]$pathToConfigurationFile,
    [Parameter(Mandatory=$True,HelpMessage="Enter the SA password you generated in MIST")]
    [string]$sapwd
)

$copyFileLocation = "C:\Temp\ConfigurationFile.ini"
$errorOutputFile = "C:\Temp\ErrorOutput.txt"
$standardOutputFile = "C:\Temp\StandardOutput.txt"
$creds = Get-Credential -Message "Enter the credentials to the Shared Dedipower server"


Write-Host -ForegroundColor Yellow "Creating new partitions as per deployment standards"
Stop-Service -Name ShellHWDetection
Get-Disk | Where-Object PartitionStyle -Eq "RAW" | Initialize-Disk -confirm:$false
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter G 
New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter L 
Format-Volume -DriveLetter G -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel "Data" -Confirm:$false -Force
Format-Volume -DriveLetter L -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel "Logs" -Confirm:$false -Force
Start-Service -Name ShellHWDetection

Write-Host -ForegroundColor Yellow "Mounting the fileshare with the installer"
New-PSDrive -Name P -PSProvider FileSystem -Root \\shared.dedipower.com\Provisioning -Credential $creds -Persist

Write-Host -ForegroundColor Yellow "Copying the ini file."
New-Item "C:\Temp" -ItemType "Directory" -Force
Copy-Item $pathToConfigurationFile $copyFileLocation -Force

Write-Host -ForegroundColor Yellow "Getting the name of the current user to replace in the copy ini file."
$user = "$env:UserDomain\$env:USERNAME"
write-host $user

Write-Host -ForegroundColor Yellow "Replacing the placeholder user name with your username"
$replaceText = (Get-Content -path $copyFileLocation -Raw) -replace "##MyUser##", $user
Set-Content $copyFileLocation $replaceText

Write-Host -ForegroundColor Yellow "Replacing the placeholder sa password with password you specified"
$replaceText2 = (Get-Content -path $copyFileLocation -Raw) -replace "##sapwd##", $sapwd
Set-Content $copyFileLocation $replaceText2

Write-Host -ForegroundColor Yellow "Mounting SQL Server Image"
$drive = Mount-DiskImage -ImagePath $isoLocation

Write-Host -ForegroundColor Yellow "Getting Disk drive of the mounted image"
$disks = Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '5'"

foreach ($disk in $disks){
 $driveLetter = $disk.DeviceID
}

if ($driveLetter)
{
 Write-Host -ForegroundColor Yellow "Starting the install of SQL Server. You might want to grab a coffee as this takes about 15 minutes!"
 Start-Process $driveLetter\Setup.exe "/ConfigurationFile=$copyFileLocation" -Wait -RedirectStandardOutput $standardOutputFile -RedirectStandardError $errorOutputFile
}

$standardOutput = Get-Content $standardOutputFile -Delimiter "\r\n"

Write-Host $standardOutput

$errorOutput = Get-Content $errorOutputFile -Delimiter "\r\n"

Write-Host $errorOutput

Write-Host -ForegroundColor Yellow "Dismounting the drive."
Dismount-DiskImage -InputObject $drive

Write-Host -ForegroundColor Green "If there is no red text then SQL Server is Successfully Installed!"

Write-Host -ForegroundColor Yellow "downloading then Installing the latest version of SQL Server Management Studio"
$InstallerSQL = $env:TEMP + “\SSMS-Setup-ENU.exe”; 
Invoke-WebRequest “https://aka.ms/ssmsfullsetup" -OutFile $InstallerSQL; 
start $InstallerSQL /Quiet

Write-Host -ForegroundColor Yellow "Installing DBA Tools PowerShell module"
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Import-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201
Install-Module -Name dbatools -Force

$SQLInstance = "localhost" #Use Your SQL Server Name

Write-Host -ForegroundColor Yellow "Changing server settings based on deployment standards"
 
##################################
## Set backup compression as default.
########################################
write-host "Set backup compression"
Set-DbaSpConfigure -SqlInstance $SQLInstance -Name 'DefaultBackupCompression' -Value 1
 
##################################
## Enable remote dedicated admin connections.
########################################
write-host "Enable remote dedicated admin connections"
Set-DbaSpConfigure -SqlInstance $SQLInstance -Name 'RemoteDacConnectionsEnabled' -Value 1
 
##################################
## Set Cost Threshold For Parallelism.
########################################
write-host "Set Cost Threshold For Parallelism"
Set-DbaSpConfigure -SqlInstance $SQLInstance -Name 'CostThresholdForParallelism' -Value 50
 
##################################
## Set Optimize For Ad-hoc Workloads.
########################################
write-host "Set Optimize For Ad-hoc Workloads"
Set-DbaSpConfigure -SqlInstance $SQLInstance -Name 'OptimizeAdhocWorkloads' -Value 1

##################################
## Set Max Degree Of Parallelism.
########################################
write-host "Set Max Degree Of Parallelism"
Set-DbaSpConfigure -SqlInstance $SQLInstance -Name 'MaxDegreeOfParallelism' -Value (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

##################################
## Automatically calculate and set maximum memory.
########################################
write-host "Set Server Max Memory"
Set-DbaMaxMemory -SqlInstance $SQLInstance

Remove-Item -Path $copyFileLocation