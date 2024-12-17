#Author: Richard Hilton
#Version: 0.18
#Purpose: Install VCSA and initially configure
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher, Posh-SSH 2.0.2 or higher

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Powershell ISE
#Changes: Adjust mail sender address, check required modules are installed.
#Adjustments Required: 


## -- Script Variables; check and/or change for every deployment -- ##

# Set variables; Installer Paths
$VCSAIsoPath = "set me"

#Set variables; Passwords
# Create the following users in MIST, and enter their passwords below.
# root, administrator@vsphere.local, vmusagemeter, orion
$VCSAUsers = @'
Name,Password
root,set me
administrator@vsphere.local,set me
vmusagemeter@vsphere.local,set me
orion@vsphere.local,set me
'@ | ConvertFrom-Csv

# Set variables; General
$CustomerAccountCode = "set me"
$Site = "set me" # MKN1 or RDG3 or EDI3 or Custom
$UseCustomDNS = $false
$CustomDNS = "set me,set me"

# Set variables; vCenter Installer
$ESXiHostName = "set me" # IP Address usually
$ESXiUserName = "root"
$ESXiHostPassword = "set me"
$VCSADeploymentNetwork = "VM Network"
$VCSADeploymentNetworkVLAN = 0 # VLAN ID as a number
$VCSADatastore = "set me"
$VCSADeploymentOption = "set me" # tiny, small, medium, large - check table and pick correct size for your deployment
$VCSASRVRCode = "set me"
$VCSAINSTCode = "set me"
$VCSADNSSuffix = "set me" # usually ".servers.dedipower.net"
$VCSAIPAddress = "set me"
$VCSAPrefixLength = "set me" # CIDR notation eg "24"
$VCSADefaultGateway = "set me"

# Set variables; vSphere License Keys
$vSpherevCenterKey = "set me"
$vSphereESXiKey = "set me"

 # Set variables; VUM
$vCenterVUMBaseline = "Host Baseline All Patches"

# Set variables; dvSwitch
$vCenterDVSwitchName = "dvSwitch"
$vCenterDVSwitchVersion = "set me" # Valid versions are 6.0.0, 6.5.0, 6.6.0.

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
$ClusterNumber = 1 # eg 1 2 3 4
$vCenterEVCMode = "set me"


## -- Script Variables; change only if required -- ##

# Set variables; Other
$TempDIR = "Z:\Provisioning\"
$VCSAJSONFileName = "VCSADeploy.json"
$VCSASetupRelativePath = ":\vcsa-cli-installer\win32\vcsa-deploy.exe"
$VCSASSHUser = "root"


# VibsDepots - does nothing, cannot be set automatically at present.
$VibsDepots = "https://vibsdepot.hpe.com/index.xml", "https://vmwaredepot.dell.com/index.xml"

# Set Variables; Start-Process Function and Log locations
$stdErrLog = $env:TEMP + "\stdErr.txt"
$stdOutLog = $env:TEMP + "\stdOut.txt"



## -- Variable manipulation -- ##

# Set variables; vCenter Installer
if ($TempDIR[-1] -eq "\") { $TempDIR = $TempDIR -replace ".$" }
$VCSAJSONFolderPath = $TempDIR + "\" + $VCSASRVRCode
$VCSAJSONFilePath = $VCSAJSONFolderPath + "\" + $VCSAJSONFileName
$Site = $Site.ToUpper()
$CustomerAccountCode = $CustomerAccountCode.ToUpper()
switch ($Site) {
    MKN1 {
        $VCSADNSServers = "212.20.226.130,212.20.226.194"
        $VCSANTPServers = "ntp1.pulsant.com,ntp2.pulsant.com"
    }
    RDG3 {
        $VCSADNSServers = "89.151.64.70,81.29.64.60"
        $VCSANTPServers = "ntp1.pulsant.com,ntp2.pulsant.com"
    }
    EDI3 {
        $VCSADNSServers = "212.20.226.130,212.20.226.194"
        $VCSANTPServers = "ntp1.pulsant.com,ntp2.pulsant.com"
    }
}

if ($UseCustomDNS -eq $true) { $VCSADNSServers = $CustomDNS }
$VCSAVMName = $VCSASRVRCode.ToUpper() + " (vCenter)"
$VCSAHostname = $VCSAINSTCode.ToLower() + $VCSADNSSuffix

# Set variables; Passwords
$VCSAPassword = ($VCSAUsers | Where-Object -Property "Name" -EQ "root").Password
$vCenterAdminPW = ($VCSAUsers | Where-Object -Property "Name" -EQ "administrator@vsphere.local").Password

# Set variables; vCenter Install Settings
$vCenterSiteName = $CustomerAccountCode + "-" + $Site

# JSON Deploy template
$VCSAJSON = @"
{
    "__version": "2.13.0",
    "__comments": "Sample template to deploy a vCenter Server Appliance with an embedded Platform Services Controller on an ESXi host.",
    "new_vcsa": {
        "esxi": {
            "hostname": "$ESXiHostName",
            "username": "$ESXiUserName",
            "password": "$ESXiHostPassword",
            "deployment_network": "$VCSADeploymentNetwork",
            "datastore": "$VCSADatastore"
        },
        "appliance": {
            "thin_disk_mode": true,
            "deployment_option": "$VCSADeploymentOption",
            "name": "$VCSAVMName"
        },
        "network": {
            "ip_family": "ipv4",
            "mode": "static",
            "ip": "$VCSAIPAddress",
            "dns_servers": [
                "$VCSADNSServers"
            ],
            "prefix": "$VCSAPrefixLength",
            "gateway": "$VCSADefaultGateway",
            "system_name": "$VCSAHostname"
        },
        "os": {
            "password": "$VCSAPassword",
            "ntp_servers": "$VCSANTPServers",
            "ssh_enable": true
        },
        "sso": {
            "password": "$vCenterAdminPW",
            "domain_name": "vsphere.local"
        }
    },
    "ceip": {
        "settings": {
            "ceip_enabled": true
        }
    }
}
"@

# Set variables; Cluster settings
$vCenterClusterName = $Site.ToLower() + $CustomerAccountCode.ToLower() + "c" + $ClusterNumber.ToString() # naming scheme to match PEC4 (Site AccountCode Cluster number) - eg: rdg3provc1

## -- Functions -- ##

Function Show-ProcessResult {
    Get-Content -Path $stdOutLog | Write-Host -ForegroundColor Green
    echo ""
    Get-Content -Path $stdErrLog | Write-Host -ForegroundColor Red
}


## -- Open connections -- #

## -- Verfication section -- ##

Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 4) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Current PowerShell version $PSVersionTable.PSVersion.Major is too old}

# Check required modules are installed
if (!(Get-Module -ListAvailable VMware.PowerCLI)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red PowerShell Module Posh-SSH is not installed}
if (!(Get-Module -ListAvailable Posh-SSH)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red PowerShell Module Posh-SSH is not installed}

# Initialize error counter
$Script:ErrorCount = 0

# Check variables; Passwords
$PasswordComplexity = "(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[^A-Za-z0-9])^.{8,20}$"

foreach ($VCSAUser in $VCSAUsers) {
    if ($VCSAUser.Password -cnotmatch $PasswordComplexity) {
        $Script:ErrorCount ++
        Write-Host
        Write-Host -ForegroundColor Red $VCSAUser.Name " password does meet the required password policy:"
        Write-Host -ForegroundColor Red "At least 8 characters, No more than 20 characters, At least 1 uppercase character, At least 1 lowercase character, At least 1 number, At least 1 special character (e.g., '!', '(', '@', etc.)`n"
    }
}
# Check variables; Installer Paths
if (!(Test-Path $VCSAIsoPath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access vCenter ISO path $VCSAIsoPath }

# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding to deploy vCenter." ; Write-Host }


### -- Script actions start here -- ##

# Update VM Network VLAN ID
$ESXiHostConnection = Connect-VIServer -Server $ESXiHostName -User $ESXiUserName -Password $ESXiHostPassword -force
Get-VirtualPortGroup -Name $VCSADeploymentNetwork | Set-VirtualPortGroup -VLanId $VCSADeploymentNetworkVLAN
$ESXiHostConnection | Disconnect-VIServer -Confirm:$False

# Mount vCenter Image
$VCSAImage = Mount-DiskImage -ImagePath $VCSAIsoPath -PassThru
$VCSAImageDriveLetter = ($VCSAImage | Get-Volume).DriveLetter

# Create VCSA JSON file
if (!(Test-Path $VCSAJSONFolderPath)) {mkdir $VCSAJSONFolderPath}
if (Test-Path $VCSAJSONFilePath) {rm $VCSAJSONFilePath}
$VCSAJSON | Out-File $VCSAJSONFilePath -Encoding ascii -Force -NoClobber

# Set VCSA Install Arguments
$VCSASetupPath = '"' + $VCSAImageDriveLetter + $VCSASetupRelativePath + '"'
$VCSAInstallArgs = @"
install --accept-eula --acknowledge-ceip --no-ssl-certificate-verification $VCSAJSONFilePath
"@

# Deploy VCSA
try { Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $VCSASetupPath -ArgumentList $VCSAInstallArgs }
catch { Show-ProcessResult ; throw }
Show-ProcessResult

# Initialize PowerCLI
Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$False -Scope Session

# Connect to vCenter
Connect-VIServer $VCSAHostname -User administrator@vsphere.local -Password $vCenterAdminPW -Force

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
$MailSender = "vcenter@" + $VCSAINSTCode + ".servers.dedipower.net"

    #Set mail settings
Get-AdvancedSetting -Entity $DefaultVIServer -Name mail.smtp.server | Set-AdvancedSetting -Value relay.pulsant.com -Confirm:$false
Get-AdvancedSetting -Entity $DefaultVIServer -Name mail.sender | Set-AdvancedSetting -Value $MailSender -Confirm:$false
        
    #View settings
Get-AdvancedSetting -Entity $DefaultVIServer -Name mail.* | ft -auto

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


## -- Password Policy, Licensing Server & VMAN Section -- ##

# Create SSH command list variable
$SSHCommands = @()

# Build commands to set SNMP settings
$SSHCommands += "snmp.set --communities E5iqcCfp"
$SSHCommands += "snmp.set --targets 46.236.30.90/E5iqcCfp"
$SSHCommands += "snmp.set --l warning"
$SSHCommands += "snmp.enable"
$SSHCommands += "snmp.test"
$SSHCommands += "snmp.get"

# Open Bash Shell
$SSHCommands += "shell"

# Build commands to add users
write-host ; write-host
foreach ($VCSAUser in ($VCSAUsers | Where-Object { $_.Name -ne $VCSASSHUser -and $_.Name -ne "administrator@vsphere.local" } ) ) {
    $VCSAShortUsername = ($VCSAUser.Name -split "@")[0]
    [string]$Command = "/usr/lib/vmware-vmafd/bin/dir-cli user create --account $VCSAShortUsername --first-name $VCSAShortUsername --last-name User --user-password '" + $VCSAUser.Password + "' --login administrator --password '$vCenterAdminPW'"
    $SSHCommands += $Command
}

# Build commands to change password policy
$SSHCommands += "echo dn: cn=password and lockout policy,dc=vsphere,dc=local >/var/tmp/change.ldif"
$SSHCommands += "echo changetype: modify >>/var/tmp/change.ldif"
$SSHCommands += "echo replace: vmwPasswordLifetimeDays >>/var/tmp/change.ldif"
$SSHCommands += "echo vmwPasswordLifetimeDays: 0 >>/var/tmp/change.ldif"
$SSHCommands += "/opt/likewise/bin/ldapmodify -f /var/tmp/change.ldif -h 127.0.0.1 -D 'cn=Administrator,cn=Users,dc=vsphere,dc=local' -w '$vCenterAdminPW'"
$SSHCommands += "rm /var/tmp/change.ldif"

# SSH to vCenter and apply commands
# foreach ($SSHCommand in $SSHCommands) {Write-Host $SSHCommand}

$VCSASSHPassword = ($VCSAUsers | Where-Object {$_.Name -eq $VCSASSHUser}).Password.ToString() | ConvertTo-SecureString -AsPlainText -Force
$VCSACredential = New-Object System.Management.Automation.PSCredential ($VCSASSHUser, $VCSASSHPassword)

$SSHSession = New-SSHSession -ComputerName $VCSAHostname -Credential $VCSACredential -Force
$SSHStream = New-SSHShellStream -SSHSession $SSHSession
Start-Sleep -Seconds 2
foreach ($SSHCommand in $SSHCommands) { $SSHStream.WriteLine($SSHCommand) }
Start-Sleep -Seconds 1
$SSHOutput = $SSHStream.Read()
Remove-SSHSession -SSHSession $SSHSession

# Add role & permission
New-VIPermission -Entity (Get-Inventory Datacenters) -Principal "vsphere.local\vmusagemeter" -Role ReadOnly
New-VIRole -Name VMAN -Privilege (Get-VIPrivilege -Role ReadOnly)
Set-VIRole -Role VMAN -AddPrivilege (Get-VIPrivilege -Id datastore.browse)
New-VIPermission -Entity (Get-Inventory Datacenters) -Principal "vsphere.local\orion" -Role VMAN

# -- vCenter Initial Configuration --
# Create Datacenter
New-Datacenter -Name $vCenterSiteName -Location Datacenters

# Create dvSwitch
New-VDSwitch -name $vCenterDVSwitchName -NumUplinkPorts 2 -Mtu 9000 -Location $vCenterSiteName -Version $vCenterDVSwitchVersion

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
Sync-Patch

# Create & Attach Host Baseline
New-PatchBaseline -TargetType Host -Name "Host Baseline All Patches" -Dynamic
Get-Baseline -Name $vCenterVUMBaseline | Attach-Baseline -Entity Datacenters

# Create Cluster
New-Cluster -Name $vCenterClusterName -Location $vCenterSiteName -DrsAutomationLevel FullyAutomated -DrsEnabled -HAEnabled -EVCMode $vCenterEVCMode


## -- Close Connections -- ##
# Unmount vCenter ISO
Dismount-DiskImage $VCSAIsoPath

# Close vCenter connection
Disconnect-VIServer $VCSAHostname

