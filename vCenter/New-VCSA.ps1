#Author: Mike Newton - Based on original by Richard Hilton
#version : 0.21
#last updated: 2021-07-02
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher, Posh-SSH 2.3.0 or higher
#Prerequisites: DNS forward and reverse records. DNS doctoring enabled on the NAT rule. 

#Last Change by: James White
#Status: New
#Recommended Run Mode: Powershell ISE
#Changes: In v0.21 - Removed redundant code fixed errors
#Adjustments Required: connecting with Posh-SSH is not working. Requested Platforms team update to version 2.3

####################################################################
#                                                                  #
#  Script Variables; check and/or change for EVERY deployment!!!!  #
#                                                                  #
####################################################################

$CustomerAccountCode = 'set me' #account e.g. PROV
$DeployToPlatform = 'set me' # options are PEC4mkn1clouc3, PEC4mkn1clouc2, PEC4edi3cloum2, PEC4edi3clouc3 PEC4rdg3clouc2
$PECVCUsername = 'set.me' # PIIP Service v2 username. Domain name is not needed e.g. james.white
$PECVCPassword = 'set me' # PIIP Service v2 password
$PECDeployment_network = 'set me' # Port group in vCenter e.g. 'PROV|PROV-AP1|PROV-EPG102'
$VCSASRVRCode = 'set me' # SRVR code of the VCSA from MIST
$VCSAINSTCode = 'set me' # the INST code of the VCSA from MIST
$VCSAIPAddress = 'set me' # Private IP of the VSCA
$VCSADefaultGateway = 'set me' # the default gateway of the VSCA
$VCSAPrefixLength = 'set me' # subnet mask in CIDR notation e.g. 24
$OrgVDC = 'set me' # enter the name of the customers vCloud VDC to move the VCSA into

# EVC mode of the cluster. Shouild match the CPU. as the time of writing these are the options
# intel-cascadeLake intel-skylake intel-broadwell intel-haswell intel-sandybridge intel-ivybridge intel-westmere intel-nehalem intel-penryn intel-merom
$vCenterEVCMode =  'set me'

# Set variables; Passwords
# Create the following users in MIST, and enter the generated passwords below.
# root, administrator@vsphere.local, vmusagemeter@vsphere.local, orion@vphere.local and ZertoVirtualManager@vsphere.local

$VCSAUsers = @'
Name,Password
root,set me
administrator@vsphere.local,set me
vmusagemeter@vsphere.local,set me
orion@vsphere.local,set me
'@ | ConvertFrom-Csv

# Set variables; dvSwitch Port Groups in CSV format
<# Example:
$vCenterDVPortGroups = @"
Name,VLAN,dvUplink1,dvUplink2
Management,10,Active,Active
vMotion,20,Active,Active
iSCSI1-Infinidat,1XXX,Active,Unused
iSCSI2-Infinidat,2XXX,Unused,Active
"@ | ConvertFrom-CSV
Valid states are: Active, Standby, Unused. If left blank, will use the VMware default.
#>

$vCenterDVPortGroups = @"
Name,VLAN,dvUplink1,dvUplink2
"@ | ConvertFrom-CSV

#############################################################
#                                                           #
#  Script Variables; check and/or change ONLY when needed   #
#                                                           #
#############################################################

# Set variables; Installer Paths
$VCSAIsoPath = "S:\Software\VMware\7.0.2\VMware-VCSA-all-7.0.2-17958471.iso" # Build 17958471 is vCenter Server 7.0 U2b

switch ($DeployToPlatform) {
PrivateCloud {
 
 }
PEC4edi3cloum2 {
 $PECVCHostname = "edi3cloum2vct01.piiplat.net"
 $PECVCSite = "edi3"
 $PECVCCluster = "edi3cloum2"
 $PECDatastore = "vvclouedi3c2vmfs05corev2"
 $ResourceGroup = 'edi3clouc2-NetworkDevices'
 }
PEC4edi3clouc3 {
 $PECVCHostname = "edi3cloum2vct01.piiplat.net"
 $PECVCSite = "edi3"
 $PECVCCluster = "edi3clouc3"
 $PECDatastore = "vvclouedi3c3vmfs04corev2"
 $ResourceGroup = 'edi3clouc3-NetworkDevices'
 }
PEC4rdg3clouc2 {
 $PECVCHostname = "rdg3cloum2vct01.piiplat.net"
 $PECVCSite = "rdg3"
 $PECVCCluster = "rdg3clouc2"
 $PECDatastore = "vvclourdg3c2vmfs11corev2"
 $ResourceGroup = 'rdg3clouc2-NetworkDevices'
 }
PEC4mkn1clouc2 {
 $PECVCHostname = "mkn1clouc2vct01.piiplat.net"
 $PECVCSite = "mkn1"
 $PECVCCluster = "mkn1clouc2"
 $PECDatastore = "vvcloumkn1c2vmfs10corev2"
 $ResourceGroup = 'mkn1clouc2-NetworkDevices'
 }
PEC4mkn1clouc3 {
 $PECVCHostname = "mkn1clouc2vct01.piiplat.net"
 $PECVCSite = "mkn1"
 $PECVCCluster = "mkn1clouc3"
 $PECDatastore = "vvcloumkn1c3vmfs02corev2"
 $ResourceGroup = 'mkn1clouc3-NetworkDevices'
 }
}

# Set variables; vCSA Installer - Common settings
$VCSADeploymentOption = "small" # tiny, small, medium, large - check table and pick correct size for your deployment
$VCSADNSSuffix = ".servers.dedipower.net" # usually ".servers.dedipower.net"


# Set variables; vSphere License Keys
$vSpherevCenterKey = "8028Q-09295-08JGT-0RGKP-11PLN"
$vSphereESXiKey = "MM48Q-6TW4H-08TG1-0ELKP-5NYQN"

 # Set variables; VUM
$vCenterVUMBaseline = "Host Baseline All Patches"

# Set variables; dvSwitch
$vCenterDVSwitchName = "dvSwitch"
$vCenterDVSwitchVersion = "7.0.0" # Valid versions are 6.0.0, 6.5.0, 6.6.0, 7.0.0.


 # Set variables; Cluster settings
$ClusterNumber = 1 # eg 1 2 3 4

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
$CustomerAccountCode = $CustomerAccountCode.ToUpper()

$VCSAVMName = $VCSASRVRCode.ToUpper() + " (VCSA)"
$VCSAHostname = $VCSAINSTCode.ToLower() + $VCSADNSSuffix

# Set variables; Passwords
$VCSAPassword = ($VCSAUsers | Where-Object -Property "Name" -EQ "root").Password
$vCenterAdminPW = ($VCSAUsers | Where-Object -Property "Name" -EQ "administrator@vsphere.local").Password

# Set variables; vCenter Install Settings
$vCenterSiteName = $CustomerAccountCode + "-" + $PECVCSite

# JSON Deploy templates

# Deploy on vCenter
$VCSAJSON_VC = @"
{
    "__version": "2.13.0",
    "__comments": "Template to deploy a vCenter Server Appliance with an embedded Platform Services Controller on a PEC4 vCenter Server instance.",
    "new_vcsa": {
        "vc": {
            "__comments": [
                "'datacenter' must end with a datacenter name, and only with a datacenter name. ",
                "'target' must end with an ESXi hostname, a cluster name, or a resource pool name. ",
                "The item 'Resources' must precede the resource pool name. ",
                "All names are case-sensitive. ",
                "For details and examples, refer to template help, i.e. vcsa-deploy {install|upgrade|migrate} --template-help"
            ],
            "hostname": "$PECVCHostname",
            "username": "$PECVCUsername",
            "password": "$PECVCPassword",
            "deployment_network": "$PECDeployment_network",
            "datacenter": [
                "$PECVCSite"
            ],
            "datastore": "$PECDatastore",
            "target": [
                "$PECVCCluster"
            ]
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
            "system_name": "$VCSAHostname",
            "prefix": "$VCSAPrefixLength",
            "gateway": "$VCSADefaultGateway",
            "dns_servers": [
                "212.20.226.130,212.20.226.194"
            ]
        },
        "os": {
            "password": "$VCSAPassword",
            "ntp_servers": "ntp1.pulsant.com,ntp2.pulsant.com",
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
$vCenterClusterName = $PECVCSite.ToLower() + $CustomerAccountCode.ToLower() + "c" + $ClusterNumber.ToString() # naming scheme to match PEC4 (Site AccountCode Cluster number) - eg: rdg3provc1

## -- Functions -- ##

Function Show-ProcessResult {
    Get-Content -Path $stdOutLog | Write-Host -ForegroundColor Green
    echo ""
    Get-Content -Path $stdErrLog | Write-Host -ForegroundColor Red
}


## -- Open connections -- #

## -- Verfication section -- ##

Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host

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

#Connect to vCenter
if (!$vCenterConnection) { $vCenterConnection = Connect-VIServer -Server $PECVCHostname -Force -ErrorAction Stop }
elseif ($vCenterConnection.IsConnected -ne $true -or $vCenterConnection.Name -notlike $PECVCHostname) { $vCenterConnection = Connect-VIServer -Server $PECVCHostname -Force -ErrorAction Stop }


# Mount vCenter Image
$VCSAImage = Mount-DiskImage -ImagePath $VCSAIsoPath -PassThru
$VCSAImageDriveLetter = ($VCSAImage | Get-Volume).DriveLetter

# Create VCSA JSON file
if (!(Test-Path $VCSAJSONFolderPath)) {mkdir $VCSAJSONFolderPath}
if (Test-Path $VCSAJSONFilePath) {rm $VCSAJSONFilePath}
$VCSAJSON_VC | Out-File $VCSAJSONFilePath -Encoding ascii -Force -NoClobber

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
Connect-VIServer $VCSAHostname -User administrator@vsphere.local -Password $vCenterAdminPW -Force -ErrorAction Stop 

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
foreach ($SSHCommand in $SSHCommands) {Write-Host $SSHCommand}

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

# Move VCSA to the customers vCloud OrgVDC #
Connect-VIServer -Server $PECVCHostname
Connect-CIServer -Server cloud.pulsant.com -User $PECVCUsername -Password $PECVCPassword
Stop-VMGuest -VM $VCSAVMName -Confirm:$false
While ((Get-VM -Name $VCSAVMName).PowerState -eq 'PoweredOn')
{
Start-Sleep -Seconds 10}
Import-CIVApp -VM (Get-VM $VCSAVMName) -OrgVdc $OrgVDC -NoCopy
Start-CIVM -VM $VCSAVMName
