#Author: Richard Hilton
#Version: 0.83
#Purpose: Install SQL 2012 Express, Install vCenter and initially configure, Install PowerCLI,
#    Install VUM, Install

#Last Change by: Richard Hilton
#Status: Had 2nd pass QA run, changes made.
#Recommended Run Mode: Semi-automatic (Powershell ISE; Manual execution section by section)
#Changes: Tidy up script to clarify user input, add validation of installer paths.
#Adjustments Required: Install-WindowsFeature Desktop-Experience, Check for pending reboots, install Vmware Remote Console, NIC Affinity for iSCSI Portgroups


## -- Script Variables; check and/or change for every deployment -- ##

#Set variables; Passwords
# Create the following users in MIST, and enter their passwords below.
# SA (SQL), vcenter (SQL), administrator@vsphere.local, vmusagemeter, orion
$ProvisioningPW = Read-Host -Prompt "Enter Provisioning user password for shared.dedipower.com"
$SAPassword = 'set me'
$vCenterDBPW = 'set me'
$vCenterAdminPW = 'set me'

#Leave below passwords on their own lines!
$LocalUsers = @'
Name,Password
vmusagemeter,set me
orion,set me
'@ | ConvertFrom-Csv

# Set variables; vSphere License Keys
$vSpherevCenterKey = "set me"
$vSphereESXiKey = "set me"

# Set variables; Installer Paths
$vCenterIsoPath = "\\shared.dedipower.com\Provisioning\ISOs\VMware\vSphere 6.5 U1\VMware-VIM-all-6.5.0-5973321.iso"
$SSMSInstallPath = "\\shared.dedipower.com\Provisioning\Software\Microsoft\SQL Server Management Studio\SSMS-Setup-ENU.exe"
#$PowerCLIInstallPath = "\\shared.dedipower.com\Provisioning\Software\VMware\VMware-PowerCLI-6.5.0-4624819.exe"
$vCenterPluginDownloadPath = "http://vsphereclient.vmware.com/vsphereclient/VMware-EnhancedAuthenticationPlugin-6.5.0.exe"
$PSPackageManagementInstallPath = "\\shared.dedipower.com\Provisioning\Software\Microsoft\PackageManagement_x64.msi"

# Set variables; vCenter Install Settings
 # $vCenterSiteName - set as AccountCode-Site, eg AA11-RDG3
 $vCenterSiteName = "set me"

 # Set variables; VUM
$vCenterVUMBaseline = "Host Baseline All Patches"

# Set variables; dvSwitch Name
$vCenterDVSwitchName = "dvSwitch"

# Set variables; dvSwitch Port Groups in CSV format
<# Example:
$vCenterDVPortGroups = @"
Name,VLAN,dvUplink1,dvUplink2
Management,10,Active,Active
vMotion,20,Active,Active
iSCSI1,30,Active,Standby
iSCSI2,40,Standby,Active
"@ | ConvertFrom-CSV

Valid states are: Active, Standby, Unused. If left blank, will use the VMware default.
#>

$vCenterDVPortGroups = @"
Name,VLAN,dvUplink1,dvUplink2

"@ | ConvertFrom-CSV


 # Set variables; Cluster settings
$vCenterClusterName = "set me" # naming scheme to match PEC4 (Site AccountCode Cluster number) - eg: rdg3provc1
$vCenterEVCMode = "intel-broadwell"


## -- Script Variables; change only if required -- ##

# Set variables; Other
$TempDIR = "D:\Pulsant\"

# VibsDepots - does nothing, cannot be set automatically at present.
$VibsDepots = "http://vibsdepot.hpe.com/index.xml", "http://vmwaredepot.dell.com/index.xml"

# Set Variables; Start-Process Function and Log locations
$stdErrLog = $env:TEMP + "\stdErr.txt"
$stdOutLog = $env:TEMP + "\stdOut.txt"

## -- Variable manipulation -- ##

# Set variables; vCenter IP Address (Automatic)
$vCenterIPAddress = Get-NetIPAddress -AddressFamily IPv4 | where { $_.InterfaceAlias -notmatch 'Loopback'} | Select -ExpandProperty IPAddress | Out-String
$vCenterIPAddress = $vCenterIPAddress -replace "`n|`r", ""

## -- Functions -- ##

Function Show-ProcessResult {
    Get-Content -Path $stdOutLog | Write-Host -ForegroundColor Green
    echo ""
    Get-Content -Path $stdErrLog | Write-Host -ForegroundColor Red
}


## -- Open connections -- #

# Open connection to shared.dedipower.com
net use \\shared.dedipower.com\Provisioning /USER:provisioning /Persistent:no $ProvisioningPW

## -- Verfication section -- ##

Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host

# Initialize error counter
$Script:ErrorCount = 0

# Check variables; administrator@vsphere.local password
$PasswordComplexity = "(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[^A-Za-z0-9])^.{8,20}$"

if ($vCenterAdminPW -cnotmatch $PasswordComplexity) {
    $Script:ErrorCount ++
    Write-Host -ForegroundColor Red "<`nadministrator@vsphere.local password does meet the required password policy:>"
    Write-Host -ForegroundColor Red "At least 8 characters, No more than 20 characters, At least 1 uppercase character, At least 1 lowercase character, At least 1 number, At least 1 special character (e.g., '!', '(', '@', etc.)`n"
}

# Check variables; Windows user passwords
foreach ($VerificationLocalUser in $LocalUsers) {
    $PW = $VerificationLocalUser.password
    # Check password complexity - match 3 out of 4 of Uppercase, Lowercase, Number, and Symbols
    if (!($PW -match "(?=.+[A-Z])(?=.+[a-z])(?=.+\d)" -or $PW -match "(?=.+[a-z])(?=.+\d)(?=.+[^A-Za-z0-9])" -or $PW -match "(?=.+[A-Z])(?=.+\d)(?=.+[^A-Za-z0-9])" -or $PW -match "(?=.+[A-Z])(?=.+[a-z])(?=.+[^A-Za-z0-9])")) {
        $Script:ErrorCount ++ ; Write-Host -Foreground Red $NewVM.Name Password is not complex enough: Requires 3 out of 4 Uppercase, Lowercase, Number, and Symbol
    }
}

# Check variables; Installer Paths
if (!(Test-Path $vCenterIsoPath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access vCenter ISO path $vCenterIsoPath }
if (!(Test-Path $SSMSInstallPath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access SQL Seerver Management Studio installer path $SSMSInstallPath }
if (!(Test-Path $PSPackageManagementInstallPath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access example path $PSPackageManagementInstallPath }

# Check variables; Installer URLs
$null = try { Invoke-WebRequest -Uri $vCenterPluginDownloadPath -DisableKeepAlive -UseBasicParsing -Method Head }
catch [Net.WebException] { $Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access VMware Enhanced Authentication Plugin installer path $vCenterPluginDownloadPath with HTTP error [int]$_.Exception.Response.StatusCode }

# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding to deploy vCenter." ; Write-Host }


### -- Script actions start here -- ##

# Add self to hosts file
if ((Get-Content "C:\Windows\System32\drivers\etc\hosts") -match $env:computername) {Write-Host $HostFileAddition ":" Already Exists} else {
    $HostFileAddition = $vCenterIPAddress + " " + $env:computername + ".servers.dedipower.net" + " " + $env:computername
    $HostFileAddition | Out-File -FilePath "C:\Windows\System32\drivers\etc\hosts" -Encoding ascii -Append
}

# Mount vCenter Image
$vCenterImage = Mount-DiskImage -ImagePath $vCenterIsoPath -PassThru
$vCenterImageDriveLetter = ($vCenterImage | Get-Volume).DriveLetter

# Extract SQL
$SQLTempDIR = $TempDIR + "SQL\"
$vCenterImageSQLInstallPath = $vCenterImageDriveLetter + ":\redist\SQLEXPR\SQLEXPR_x64_ENU.exe"
md $SQLTempDIR
$vCenterImageSQLExtractArgs = @"
/q /X:$SQLTempDIR
"@
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $vCenterImageSQLInstallPath -ArgumentList $vCenterImageSQLExtractArgs
Show-ProcessResult

# Set SQL Install Arguments
$SQLInstallPath = $SQLTempDIR + "setup.exe"
$SQLInstallArgs = @"
/Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /PID="11111-00000-00000-00000-00000" /ERRORREPORTING=True /SQMREPORTING=True /UpdateEnabled /FEATURES=SQL,Tools /INSTALLSHAREDDIR="D:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="D:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME="SQLExpress" /INSTANCEID="SQLEXPRESS" /INSTANCEDIR="D:\Program Files\Microsoft SQL Server" /SECURITYMODE=SQL /ADDCURRENTUSERASSQLADMIN /SAPWD="$SAPassword" /INDICATEPROGRESS
"@

# Install SQL
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $SQLInstallPath -ArgumentList $SQLInstallArgs
Show-ProcessResult

#Enable SQL Server Browser Service
Set-Service SQLBrowser -StartupType Automatic
Start-Service SQLBrowser

# Copy SQL Server Management Studio Installer
$SMSSTempInstallPath = $TempDIR + "SMSS\"
$SSMSInstallFilename = (Get-ItemProperty $SSMSInstallPath).Name
$SSMSTempInstallFullPath = $SMSSTempInstallPath + $SSMSInstallFilename
md $SMSSTempInstallPath
Copy-Item -Path $SSMSInstallPath -Destination $SMSSTempInstallPath

# Set SQL Server Management Studio Install Arguments
$SSMSInstallArgs = @"
/install /passive
"@

# Install SQL Server Management Studio
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $SSMSTempInstallFullPath -ArgumentList $SSMSInstallArgs
Show-ProcessResult

# Refresh Path Variable to allow script to find SQLCMD
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")

# Create Databases
$SQLCMDArgs = @"
-S localhost\SQLEXPRESS -Q "USE master; create database VCDB; create database VUMDB"
"@ , @"
-S localhost\SQLEXPRESS -Q "ALTER DATABASE [VCDB] MODIFY FILE ( NAME = N'VCDB', SIZE = 100MB, FILEGROWTH = 100MB ); ALTER DATABASE [VCDB] MODIFY FILE ( NAME = N'VCDB_log', SIZE = 100MB, FILEGROWTH = 10MB )"
"@ , @"
-S localhost\SQLEXPRESS -Q "ALTER DATABASE [VUMDB] MODIFY FILE ( NAME = N'VUMDB', SIZE = 100MB, FILEGROWTH = 10MB ); ALTER DATABASE [VUMDB] MODIFY FILE ( NAME = N'VUMDB_log', SIZE = 25MB, FILEGROWTH = 2MB )"
"@ , @"
-S localhost\SQLEXPRESS -Q "USE master; CREATE LOGIN vcenter WITH PASSWORD = '$vCenterDBPW'"
"@ , @"
-S localhost\SQLEXPRESS -Q "sp_addsrvrolemember vcenter, sysadmin"
"@ , @"
-S localhost\SQLEXPRESS -Q "USE VCDB; EXEC sp_changedbowner vcenter"
"@ , @"
-S localhost\SQLEXPRESS -Q "USE VUMDB; EXEC sp_changedbowner vcenter"
"@

# foreach ($SQLCMDArg in $SQLCMDArgs) { Start-Process -Wait -FilePath $SQLCMDPath -ArgumentList $SQLCMDArg }
foreach ($SQLCMDArg in $SQLCMDArgs) {
    Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath SQLCMD -ArgumentList $SQLCMDArg
    Show-ProcessResult
}
# Start-Process -Wait -FilePath $SQLCMDPath -ArgumentList $SQLCMDArgs[0]

# Configure SQL TCP/IP
 # Load SMO Wmi.ManagedComputer assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | out-null
 # Connect to the instance using SMO
$SQLMO = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer')
$SQLURN = "ManagedComputer[@Name='$env:computername']/ServerInstance[@Name='SQLEXPRESS']/ServerProtocol[@Name='Tcp']"
 # Enable TCP/IP
$SQLTCP = $SQLMO.GetSmoObject($SQLURN)
$SQLTCP.IsEnabled = $true
$SQLMO.GetSmoObject($SQLURN + "/IPAddress[@Name='IPAll']").IPAddressProperties[1].Value = "1433"
$SQLTCP.alter()
Restart-Service "SQL Server (SQLEXPRESS)"

# Create ODBC connection
Add-OdbcDsn -Name VCDB -DsnType System -Platform 64-bit -DriverName "SQL Server Native Client 11.0" -SetPropertyValue @("Server=.\sqlexpress", "Database=VCDB")
Add-OdbcDsn -Name VUMDB -DsnType System -Platform 64-bit -DriverName "SQL Server Native Client 11.0" -SetPropertyValue @("Server=.\sqlexpress", "Database=VUMDB")


# Set vCenter Install & Temp Paths
$vCenterInstallPath = $vCenterImageDriveLetter + ":\vCenter-Server\VMware-vCenter-Server.exe"
$vCenterInstallConfigPath = $TempDIR + "vCenter\"
md $vCenterInstallConfigPath
$vCenterInstallConfigFile = $vCenterInstallConfigPath + "Settings.json"

# Build vCenter json config
$vCenterJson = [pscustomobject]@{
    "appliance.net.pnid" = "$env:computername" +  ".servers.dedipower.net"
    "ceip_enabled" = $false
    "clientlocale" = "en"
    "db.clobber" = $null
    "db.dsn" = "VCDB"
    "db.password" = $vCenterDBPW
    "db.type" = "external"
    "db.user" = "vcenter"
    "deployment.node.type" = "embedded"
    "feature.states" = $null
    "install.type" = "install"
    "machine.cert.replacement" = $null
    "silentinstall" = $null
    "system.vm0.hostname" = $null
    "system.vm0.port" = "443"
    "upgrade.import.directory" = $null
    "upgrade.src.version" = $null
    "vc.5x.password" = $null
    "vc.5x.username" = $null
    "vc.svcuser" = $null
    "vc.svcuserpassword" = $null
    "vcdb.migrate.set" = "all"
    "vmdir.cert.thumbprint" = $null
    "vmdir.domain-name" = "vsphere.local"
    "vmdir.first-instance" = $true
    "vmdir.password" = $vCenterAdminPW
    "vmdir.replication-partner-hostname" = $null
    "vmdir.site-name" = $vCenterSiteName
}

# Export vCenter config to json file
$vCenterJson | ConvertTo-Json | Out-File -FilePath $vCenterInstallConfigFile -Encoding ascii

# Debug Only
 #notepad $vCenterInstallConfigFile

# Set vCenter Install Args
$vCenterInstallArgs1 = "PREINSTALLCHECK=1 EXPORT_SETTINGS_DIR=$vCenterInstallConfigPath"
$vCenterInstallArgs2 = "/qr PREINSTALLCHECK=1 CUSTOM_SETTINGS=$vCenterInstallConfigFile"
$vCenterInstallArgs3 = "/qr CUSTOM_SETTINGS=$vCenterInstallConfigFile"
$vCenterInstallArgs4 = "PREINSTALLCHECK=1 CUSTOM_SETTINGS=$vCenterInstallConfigFile"

 # Debug Only
    #Run the below to generate a new settings.json file - useful for updating above settings for a new version of vCenter
    #Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $vCenterInstallPath -ArgumentList $vCenterInstallArgs1
    #Show-ProcessResult

# Run vCenter pre-install check
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $vCenterInstallPath -ArgumentList $vCenterInstallArgs2
Show-ProcessResult
& $env:USERPROFILE\AppData\Local\Temp\vim-vcs-precheck-report-65.html
Pause

# Install vCenter
echo "Ready to install vCenter"
Pause
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $vCenterInstallPath -ArgumentList $vCenterInstallArgs3
Show-ProcessResult
Pause

 # Debug Only
    #Run below to manually re-run with full UI - useful for troubleshooting.
    #Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $vCenterInstallPath -ArgumentList $vCenterInstallArgs4

# Copy vSphere Web Client Shortcut to Desktop
Copy-Item "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\VMware\vCenterServer\VMware vSphere WebClient.lnk" -Destination "C:\Users\Public\Desktop"

# Copy Powershell Package Management Installer (NEW)
$PSPackageManagementTempInstallPath = $TempDIR + "PSGallery\"
$PSPackageManagementInstallFilename = (Get-ItemProperty $PSPackageManagementInstallPath).Name
$PSPackageManagementTempInstallFullPath = $PSPackageManagementTempInstallPath + $PSPackageManagementInstallFilename
md $PSPackageManagementTempInstallPath
Copy-Item -Path $PSPackageManagementInstallPath -Destination $PSPackageManagementTempInstallPath

# Install Powershell Package Management (NEW)
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath msiexec -ArgumentList "/i $PSPackageManagementTempInstallFullPath /q"
Show-ProcessResult

# Install PowerCLI (NEW)
# C:\Pulsant\PackageManagement_x64.msi /q
Install-PackageProvider -Name NuGet -Force
Install-Module -Name VMware.PowerCLI -Force
Get-Module VMware* -ListAvailable

# Import Settings.json
$vCenterSettings = Get-Content -Raw -Path $vCenterInstallConfigFile | ConvertFrom-Json


# Initialize PowerCLI
Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$False

# Connect to vCenter
Connect-VIServer localhost -User administrator@vsphere.local -Password $vCenterAdminPW

# Add permissions for local administrator
New-VIPermission -Entity (Get-Inventory Datacenters) -Principal "Administrator" -Role Admin

# Add License Keys to vCenter
$vCenterView = Get-View $DefaultVIServer
$LicMgr = Get-View $vCenterView.Content.LicenseManager
$LicMgr.AddLicense($vSpherevCenterKey,$null)
$LicMgr.AddLicense($vSphereESXiKey,$null)

# Assign vCenter license
$LicenseAssignmentManager = get-view ($LicMgr.licenseAssignmentManager)
$LicenseAssignmentManager.UpdateAssignedLicense($DefaultVIServer.InstanceUuid,$vSpherevCenterKey,$Null)


# -- Alert Section --
    #Build Variables
$mailsender = "vcenter." + $env:computername + "@service.pulsant.com"
$mailsender

    #Set mail settings
Get-AdvancedSetting -Entity localhost -Name mail.smtp.server | Set-AdvancedSetting -Value relay.pulsant.com -Confirm:$false
Get-AdvancedSetting -Entity localhost -Name mail.sender | Set-AdvancedSetting -Value $mailsender -Confirm:$false

    #View settings
Get-AdvancedSetting -Entity localhost -Name mail.* | ft -auto

    #Adjust alarms
        #Cannot Connect to Storage
    $vCenterAlarmDefinition = "Cannot Connect to Storage"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Cannot find vSphere HA master agent
    $vCenterAlarmDefinition = "Cannot find vSphere HA master agent"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Datastore usage on disk
    $vCenterAlarmDefinition = "Datastore usage on disk"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Exit standby error
    $vCenterAlarmDefinition = "Exit standby error"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #Health status changed alarm
    $vCenterAlarmDefinition = "Health status changed alarm"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #Health status monitoring
    $vCenterAlarmDefinition = "Host Baseboard Management Controller status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Green -EndStatus Yellow
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Red -EndStatus Yellow

        #Host battery status
    $vCenterAlarmDefinition = "Host battery status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Host connection and power state
    $vCenterAlarmDefinition = "Host connection and power state"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Host connection failure
    $vCenterAlarmDefinition = "Host connection failure"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Green -EndStatus Yellow
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Red -EndStatus Yellow

        #Host cpu usage
    $vCenterAlarmDefinition = "Host cpu usage"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Green -EndStatus Yellow
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Red -EndStatus Yellow
            # Update Definition Trigger Thresholds for Host cpu usage
        $viewAlarmToUpdate = Get-View -Id (Get-AlarmDefinition -Name $vCenterAlarmDefinition).Id
        $specNewAlarmInfo = $viewAlarmToUpdate.Info
        $specNewAlarmInfo.Expression.Expression[0].YellowInterval = 900
        $specNewAlarmInfo.Expression.Expression[0].Red = 9500
        $specNewAlarmInfo.Expression.Expression[0].RedInterval = 600
        $viewAlarmToUpdate.ReconfigureAlarm($specNewAlarmInfo)

        #Host error
    $vCenterAlarmDefinition = "Host error"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #Host hardware fan status
    $vCenterAlarmDefinition = "Host hardware fan status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Host hardware power status
    $vCenterAlarmDefinition = "Host hardware power status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Green -EndStatus Yellow
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Red -EndStatus Yellow

        #Host hardware temperature status
    $vCenterAlarmDefinition = "Host hardware temperature status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Host memory status
    $vCenterAlarmDefinition = "Host memory status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"

        #Host memory usage
    $vCenterAlarmDefinition = "Host memory usage"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
            # Update Definition Trigger Thresholds for Host memory usage
        $viewAlarmToUpdate = Get-View -Id (Get-AlarmDefinition -Name $vCenterAlarmDefinition).Id
        $specNewAlarmInfo = $viewAlarmToUpdate.Info
        $specNewAlarmInfo.Expression.Expression[0].YellowInterval = 600
        $viewAlarmToUpdate.ReconfigureAlarm($specNewAlarmInfo)

        #Host processor status
    $vCenterAlarmDefinition = "Host processor status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"


        #Host storage status
    $vCenterAlarmDefinition = "Host storage status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"

        #License error
    $vCenterAlarmDefinition = "License error"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #Migration error
    $vCenterAlarmDefinition = "Migration error"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"

        #Network connectivity lost
    $vCenterAlarmDefinition = "Network connectivity lost"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Green -EndStatus Yellow
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Red -EndStatus Yellow

        #Network uplink redundancy degraded
    $vCenterAlarmDefinition = "Network uplink redundancy degraded"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #Network uplink redundancy lost
    $vCenterAlarmDefinition = "Network uplink redundancy lost"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #No compatible host for Secondary VM
    $vCenterAlarmDefinition = "No compatible host for Secondary VM"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #Timed out starting Secondary VM
    $vCenterAlarmDefinition = "Timed out starting Secondary VM"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #Virtual machine cpu usage
    $vCenterAlarmDefinition = "Virtual machine cpu usage"
    Set-AlarmDefinition $vCenterAlarmDefinition -Enabled $False

      #Virtual Machine CPU Ready time
    $vCenterAlarmDefinition = "Virtual Machine CPU Ready time"
          # Create AlarmSpec object
        $alarm = New-Object VMware.Vim.AlarmSpec
        $alarm.Name = $vCenterAlarmDefinition
        $alarm.Description = "$vCenterAlarmDefinition"
        $alarm.Enabled = $TRUE
          # Expression
        $expression1 = New-Object VMware.Vim.MetricAlarmExpression
        $expression1.Operator = "isAbove"
        $expression1.Type = "VirtualMachine"
        $expression1.Yellow = 15000
        $expression1.YellowInterval = 600
        $expression1.Red = 20000
        $expression1.RedInterval = 900
          # Add metric info to expression
        $expression1.metric = New-Object VMware.Vim.PerfMetricId
        $expression1.metric.counterid = "12"
        $expression1.metric.instance = ""
          # Add event expressions to alarm
        $alarm.expression = New-Object VMware.Vim.OrAlarmExpression
        $alarm.expression.expression += $expression1
          # Create alarm in vCenter root
        $alarmMgr = Get-View AlarmManager
        $alarmMgr.CreateAlarm("Folder-group-d1",$alarm)
        # Add Alarm Actions
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"

      #Host service console swap rates
    $vCenterAlarmDefinition = "Host service console swap rates"
          # Create AlarmSpec object
        $alarm = New-Object VMware.Vim.AlarmSpec
        $alarm.Name = $vCenterAlarmDefinition
        $alarm.Description = "$vCenterAlarmDefinition"
        $alarm.Enabled = $TRUE
          # Expression 1
        $expression1 = New-Object VMware.Vim.MetricAlarmExpression
        $expression1.Operator = "isAbove"
        $expression1.Type = "HostSystem"
        $expression1.Yellow = 512
        $expression1.YellowInterval = 60
        $expression1.Red = 2048
        $expression1.RedInterval = 60
        $expression1.metric = New-Object VMware.Vim.PerfMetricId
        $expression1.metric.counterid = "87"
        $expression1.metric.instance = "cos"
          # Expression 2
        $expression2 = New-Object VMware.Vim.MetricAlarmExpression
        $expression2.Operator = "isAbove"
        $expression2.Type = "HostSystem"
        $expression2.Yellow = 512
        $expression2.YellowInterval = 60
        $expression2.Red = 2048
        $expression2.RedInterval = 60
        $expression2.metric = New-Object VMware.Vim.PerfMetricId
        $expression2.metric.counterid = "88"
        $expression2.metric.instance = "cos"
          # Add event expressions to alarm
        $alarm.expression = New-Object VMware.Vim.OrAlarmExpression
        $alarm.expression.expression += $expression1
        $alarm.expression.expression += $expression2
          # Create alarm in vCenter root
        $alarmMgr = Get-View AlarmManager
        $alarmMgr.CreateAlarm("Folder-group-d1",$alarm)

        #Virtual machine error
    $vCenterAlarmDefinition = "Virtual machine error"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #VMKernel NIC not configured correctly
    $vCenterAlarmDefinition = "VMKernel NIC not configured correctly"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #vSphere HA failover in progress
    $vCenterAlarmDefinition = "vSphere HA failover in progress"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #vSphere HA host status
    $vCenterAlarmDefinition = "vSphere HA host status"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #vSphere HA virtual machine failover failed
    $vCenterAlarmDefinition = "vSphere HA virtual machine failover failed"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"

        #vSphere HA virtual machine monitoring error
    $vCenterAlarmDefinition = "vSphere HA virtual machine monitoring error"
    Set-AlarmDefinition $vCenterAlarmDefinition -ActionRepeatMinutes 5

        #
    $vCenterAlarmDefinition = ""


        #Show full alarm info (debugging)
    #$vCenterAlarmDefinition = "Cannot Connect to Storage"
    #Get-AlarmDefinition $vCenterAlarmDefinition | fl
    #(Get-View -Id (Get-AlarmDefinition -Name $vCenterAlarmDefinition).Id).Info.Expression.Expression
    #(Get-View -Id (Get-AlarmDefinition -Name $vCenterAlarmDefinition).Id).Info.Expression.Expression.Metric
    #Get-AlarmDefinition $vCenterAlarmDefinition | Get-AlarmAction | fl
    #Get-AlarmDefinition $vCenterAlarmDefinition | Get-AlarmAction | Get-AlarmActionTrigger | fl
    #Get-AlarmDefinition $vCenterAlarmDefinition | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | fl


## -- Licensing Server & VMAN Section -- ##
#Add Users & disable password expiry
foreach ($LocalUser in $LocalUsers) {
    [string]$ConnectionString = "WinNT://localhost,computer"
    $ADSI = [adsi]$ConnectionString
    $User = $ADSI.Create("user",$LocalUser.Name)
    $User.SetPassword($LocalUser.Password)
    $User.UserFlags = 65536
    $User.SetInfo()
}

#Add role & permission
New-VIPermission -Entity (Get-Inventory Datacenters) vmusagemeter -Role ReadOnly
New-VIRole -Name VMAN -Privilege (Get-VIPrivilege -Role ReadOnly)
Set-VIRole -Role VMAN -AddPrivilege (Get-VIPrivilege -Id datastore.browse)
New-VIPermission -Entity (Get-Inventory Datacenters) orion -Role VMAN

#Install VMware Update Manager
$vCenterUpdateManagerDataLocation = "D:\ProgramData\VMware\VMware Update Manager\Data\"
$vCenterVUMInstallPath = $vCenterImageDriveLetter + ":\updateManager\VMware-UpdateManager.exe"
$vCenterVUMInstallArgs = @"
/s /V"/qr VCI_DB_SERVER_TYPE=Custom DB_DSN=VUMDB DB_USERNAME=vcenter DB_PASSWORD=$vCenterDBPW VC_SERVER_IP=$vCenterIPAddress VC_SERVER_ADMIN_USER=Administrator@vsphere.local VC_SERVER_ADMIN_PASSWORD=$vCenterAdminPW VMUM_SERVER_SELECT=$vCenterIPAddress VMUM_DATA_DIR=\"$vCenterUpdateManagerDataLocation\""
"@
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $vCenterVUMInstallPath -ArgumentList $vCenterVUMInstallArgs
Show-ProcessResult

# Download & Install vCenter Web Plugins (NEW)
$vCenterPluginFilename = $vCenterPluginDownloadPath.Substring($vCenterPluginDownloadPath.LastIndexOf("/") + 1)
$vCenterPluginInstallPath = "$TempDIR" + "\vCenter\" + $vCenterPluginFilename
$vCenterPluginInstallArgs = "/q"
Invoke-WebRequest -Uri $vCenterPluginDownloadPath -OutFile $vCenterPluginInstallPath
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $vCenterPluginInstallPath -ArgumentList $vCenterPluginInstallArgs
Show-ProcessResult

# -- vCenter Initial Configuration --
# Create Datacenter
New-Datacenter -Name $($vCenterSettings.'vmdir.site-name') -Location Datacenters

# Create dvSwitch
New-VDSwitch -name $vCenterDVSwitchName -NumUplinkPorts 2 -Mtu 9000 -Location $($vCenterSettings.'vmdir.site-name')

# Create dvSwitch Port Groups
foreach ($vCenterDVPortGroup in $vCenterDVPortGroups) {
    $vCenterDVPortGroupFullName = $vCenterDVPortGroup.Name + " - VLAN" + $vCenterDVPortGroup.VLAN
    New-VDPortgroup -VDSwitch $vCenterDVSwitchName -Name $vCenterDVPortGroupFullName -VlanId $vCenterDVPortGroup.VLAN

    $vCenterDVSwitchPortGroupObject = Get-VDSwitch $vCenterDVSwitchName | Get-VDPortgroup $vCenterDVPortGroupFullName

    switch ($vCenterDVPortGroup.dvUplink1) {
        Active { Get-VDUplinkTeamingPolicy -VDPortgroup $vCenterDVPortGroupFullName | Set-VDUplinkTeamingPolicy -ActiveUplinkPort dvUplink1 }
        Standby { Get-VDUplinkTeamingPolicy -VDPortgroup $vCenterDVPortGroupFullName | Set-VDUplinkTeamingPolicy -StandbyUplinkPort dvUplink1 }
        Unused { Get-VDUplinkTeamingPolicy -VDPortgroup $vCenterDVPortGroupFullName | Set-VDUplinkTeamingPolicy -UnusedUplinkPort dvUplink1 }
    }

    switch ($vCenterDVPortGroup.dvUplink2) {
        Active { Get-VDUplinkTeamingPolicy -VDPortgroup $vCenterDVPortGroupFullName | Set-VDUplinkTeamingPolicy -ActiveUplinkPort dvUplink2 }
        Standby { Get-VDUplinkTeamingPolicy -VDPortgroup $vCenterDVPortGroupFullName | Set-VDUplinkTeamingPolicy -StandbyUplinkPort dvUplink2 }
        Unused { Get-VDUplinkTeamingPolicy -VDPortgroup $vCenterDVPortGroupFullName | Set-VDUplinkTeamingPolicy -UnusedUplinkPort dvUplink2 }
    }
}
Get-VDSwitch $vCenterDVSwitchName | Get-VDPortgroup | Get-VDUplinkTeamingPolicy | ft VDPortGroup,UplinkPortOrderInherited,ActiveUplinkPort,StandbyUplinkPort,UnusedUplinkPort -AutoSize

# Add manufacturer vibs depots to Update Manager ##MANUAL
#bug: Command below doesn't work; it's for use with vmware image builder not update manager.
#Doesn't seem to be a cmdlet that can do this.
#foreach ($VibsDepot in $VibsDepots) { Add-EsxSoftwareDepot -DepotUrl $VibsDepot }
Write-Host "# Add manufacturer vibs depots to Update Manager ##MANUAL"
$VibsDepots
Pause


# Download patch definitions
Download-Patch

# Create & Attach Host Baseline
New-PatchBaseline -TargetType Host -Name "Host Baseline All Patches" -Dynamic
Get-Baseline -Name $vCenterVUMBaseline | Attach-Baseline -Entity Datacenters

# Create Cluster
New-Cluster -Name $vCenterClusterName -Location $vCenterSiteName -DrsAutomationLevel FullyAutomated -DrsEnabled -HAEnabled -EVCMode $vCenterEVCMode


## -- Close Connections -- ##
# Unmount vCenter ISO
Dismount-DiskImage $vCenterIsoPath

# Close connection to shared.dedipower.com
Net use /delete \\shared.dedipower.com\Provisioning

# Close vCenter connection

