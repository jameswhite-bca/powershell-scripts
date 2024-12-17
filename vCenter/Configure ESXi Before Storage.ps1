#Author: Richard Hilton
#Version: 2.6
#Purpose: Join hosts to vCenter and set the base configuration for them. No local storage is required.

#Last Change by: Richard Hilton
#Changes: Minor updates
#Adjustments Required:

# Set Variables; vCenter
$vCenterType = "set me" # Appliance or Windows
$vCenterAddress = "set me" # Address for Appliance, "localhost" for Windows as the script must be run on the vCenter
$vCenterAdminUser = "set me" # Only for Appliance, passthrough authentication is used for Windows as the script must be run on the vCenter
$vCenterAdminPW = 'set me' # Only for Appliance, passthrough authentication is used for Windows as the script must be run on the vCenter
$VCSAAdminUser = "set me" # Only for Appliance, passthrough authentication is used for Windows as the script must be run on the vCenter
$VCSAAdminPW = 'set me' # Only for Appliance, passthrough authentication is used for Windows as the script must be run on the vCenter


# Set Variables; ESXi Hosts
# FQDNs of ESXi Hosts to Configure, and passwords
# Example:
# $ESXiHosts @'
# Name,IPAddress,vMotionIPAddress,vMotionSubnetMask,Password,AddToDVSwitch,RemoveVSwitch,AddvMotionVMKernel,EnterMaintenanceMode,JoinCluster,ChangePW,NewPW
# inst-00000001.servers.dedipower.net,172.22.10.11,172.22.20.11,255.255.255.0,password1,Yes,Yes,Yes,No,Yes,Yes,password11
# inst-00000002.servers.dedipower.net,172.22.10.12,172.22.20.12,255.255.255.0,password2,Yes,Yes,Yes,No,Yes,Yes,password22
# inst-00000003.servers.dedipower.net,172.22.10.13,172.22.20.13,255.255.255.0,password3,Yes,Yes,Yes,No,Yes,Yes,password33
# '@ | ConvertFrom-Csv

$ESXiHosts = @'
Name,IPAddress,vMotionIPAddress,vMotionSubnetMask,Password,AddToDVSwitch,RemoveVSwitch,AddvMotionVMKernel,EnterMaintenanceMode,JoinCluster,ChangePW,NewPW

'@ | ConvertFrom-Csv

$ESXiHosts = $ESXiHosts | Out-GridView -PassThru -Title "Select ESXi Hosts to configure"

# Set Variables; Site
$Site = "set me" # RDG2, RDG3, MKN1 or Custom

if ($Site -eq "RDG2" -or $Site -eq "RDG3") {
  # Reading Values
    $DNSDomainName = "servers.dedipower.net"
    $DNS1 = "89.151.64.70"
    $DNS2 = "81.29.64.60"
    $NTP1 = "ntp1.pulsant.com"
    $NTP2 = "ntp2.pulsant.com"
    $Syslog = "udp://rdg3-syslog.pulsant.net:514"
}

ElseIf ($Site -eq "MKN1") {
  # Milton Keynes Values
    $DNSDomainName = "servers.dedipower.net"
    $DNS1 = "212.20.226.130"
    $DNS2 = "212.20.226.194"
    $NTP1 = "ntp1.pulsant.com"
    $NTP2 = "ntp2.pulsant.com"
    $Syslog = "udp://rdg3-syslog.pulsant.net:514"
}

ElseIf ($Site -eq "Custom") {
  # Custom Values
    $DNSDomainName = "set me"
    $DNS1 = "set me"
    $DNS2 = "set me"
    $NTP1 = "set me"
    $NTP2 = "set me"
    $Syslog = "set me"
  }
  
Else {Write-Host "Site not correctly specified, cancel execution or window will close" "You have 30 seconds to comply."; Start-Sleep 30; exit}

# Set variables; dvSwitch
$vCenterDVSwitchName = "set me" # Example: "dvSwitch"
$VMHostPhysicalNICs = "set me" , "set me" # Example: "vmnic0", "vmnic1"
$vCenterDVPortGroupManagement = "Management"
$vCenterDVPortGroupvMotion = "vMotion"

# Set variables; Cluster to join
$vCenterClusterName = "set me"


# -- Script actions start here --

#Initialize PowerCLI
#. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
#. "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true -InvalidCertificateAction Warn

#Connect to vCenter
switch ($vCenterType) {
    Windows { Connect-VIServer $vCenterAddress }
    Appliance {
        Connect-VIServer $vCenterAddress -User $vCenterAdminUser -Password $vCenterAdminPW
        $VCSAHostname = $vCenterAddress
        $SSHCommands = @()
        $SSHCommands += "shell"
        $VCSASSHUser = $VCSAAdminUser
        $VCSASSHPassword = $VCSAAdminPW | ConvertTo-SecureString -AsPlainText -Force
        $VCSACredential = New-Object System.Management.Automation.PSCredential ($VCSASSHUser, $VCSASSHPassword)
        $SSHSession = New-SSHSession -ComputerName $VCSAHostname -Credential $VCSACredential -Force
        $SSHStream = New-SSHShellStream -SSHSession $SSHSession
        Start-Sleep -Seconds 2
    }
}

# Add ESXi Hosts to hosts file
switch ($vCenterType) {
    Windows {
        Foreach ($ESXiHost in $ESXiHosts) {
            if ((Get-Content "C:\Windows\System32\drivers\etc\hosts") -match $ESXiHost.Name) {Write-Host $ESXiHost.Name ":" Already Exists} else {
                $ESXiHostShortName = $ESXiHost.Name.Substring(0,($ESXiHost.Name.IndexOf(".")))
                $HostFileAddition = $ESXiHost.IPAddress + " " + $ESXiHost.Name + " " + $ESXiHostShortName
                $HostFileAddition | Out-File -FilePath "C:\Windows\System32\drivers\etc\hosts" -Encoding ascii -Append
            }
        }
    }
    Appliance {
        Foreach ($ESXiHost in $ESXiHosts) {
            $ESXiHostShortName = $ESXiHost.Name.Substring(0,($ESXiHost.Name.IndexOf(".")))
            $HostFileAddition = $ESXiHost.IPAddress + " " + $ESXiHost.Name + " " + $ESXiHostShortName
            $SSHCommands += "if grep -wiq '$ESXiHostShortName' /etc/hosts; then echo exists; else echo $HostFileAddition >>/etc/hosts; fi"
        }
        $SSHCommands
        foreach ($SSHCommand in $SSHCommands) { $SSHStream.WriteLine($SSHCommand) }
        $SSHCommands = @()
        Start-Sleep -Seconds 1
        $SSHOutput = $SSHStream.Read()

    }
}

# Add hosts to vCenter
Foreach ($ESXiHost in $ESXiHosts) {Add-VMHost -Name $ESXiHost.Name -Location (Get-Datacenter) -User root -Password $ESXiHost.Password -Force}

#License hosts
$vCenterView = Get-View $DefaultVIServer
$LicMgr = Get-View $vCenterView.Content.LicenseManager
$ESXiLicense = $LicMgr | Select-Object -ExpandProperty Licenses | Where-Object {$_.name -like "*vSphere*"}
Foreach ($ESXiHost in $ESXiHosts) {Set-VMHost -VMHost $ESXiHost.Name -LicenseKey $ESXiLicense.LicenseKey }

#View Shell & SSH settings
Foreach ($ESXiHost in $ESXiHosts) {
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "TSM"}
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "TSM-SSH"}
}

#Enable Shell & SSH, Disable warning
Foreach ($ESXiHost in $ESXiHosts) {
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "TSM"} | Set-VMHostService -policy "on" -Confirm:$false
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "TSM"} | Restart-VMHostService -Confirm:$false
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "TSM-SSH"} | Set-VMHostService -policy "on" -Confirm:$false
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "TSM-SSH"} | Restart-VMHostService -Confirm:$false
    Get-AdvancedSetting $ESXiHost.Name -Name UserVars.SuppressShellWarning |  Set-AdvancedSetting -Value 1 -Confirm:$false
}

#Set DNS & NTP
Foreach ($ESXiHost in $ESXiHosts) {
    Get-VMHostNetwork -VMHost $ESXiHost.Name | Set-VMHostNetwork -DnsAddress $DNS1 , $DNS2 -DomainName $DNSDomainName
    #Clear & Set NTP Servers
    $OldNTPServers = Get-VMHostNTPServer -VMHost $ESXiHost.Name
    foreach ($OldNTPServer in $OldNTPServers) {Remove-VMHostNtpServer -VMHost $ESXiHost.Name -NtpServer $OldNTPServer -Confirm:$false}
    Add-VMHostNTPServer -VMHost $ESXiHost.Name -NtpServer $NTP1 , $NTP2 -Confirm:$false
}

#Enable NTP
Foreach ($ESXiHost in $ESXiHosts) {
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "ntpd"} | Restart-VMHostService -Confirm:$false
}

#Configure & Enable SNMP
Foreach ($ESXiHost in $ESXiHosts) {
    $esxcli = Get-EsxCli -VMHost $ESXiHost.Name
    $esxcli.system.snmp.set($null, "E5iqcCfp", $true, $null, $null, $null, "warning", $null, $null, $null, $null, $null, $null, $null, "46.236.30.90@162 E5iqcCfp")
    Start-Sleep 1
    $esxcli.system.snmp.test()
    $esxcli.system.snmp.get()
    #Start-Sleep 2
    Get-VMHostService -VMHost $ESXiHost.Name | Where-Object {$_.Key -eq "snmpd"} | Restart-VMHostService -Confirm:$false
}


#Configure RAID Controller settings (HP / HPE only)
Foreach ($ESXiHost in $ESXiHosts) {
    if ((Get-VMHost $ESXiHost.Name).Manufacturer -like "*HP*") {
        $esxcli = Get-EsxCli -VMHost $ESXiHost.Name
        $esxcli.ssacli.cmd("ctrl all show status") | Write-Host -Foreground Cyan
        $esxcli.ssacli.cmd("ctrl slot=0 logicaldrive 1 modify arrayaccelerator=enable forced")
        $esxcli.ssacli.cmd("ctrl slot=0 modify cr=50/50")
        $esxcli.ssacli.cmd("ctrl slot=0 modify dwc=enable forced")
        $esxcli.ssacli.cmd("ctrl all show config detail") |
        findstr /c:"Cache Ratio:" /c:"Drive Write Cache:" /c:"LD Acceleration Method:" | Write-Host -Foreground Cyan
    }
}

#Rename default datastore
Foreach ($ESXiHost in $ESXiHosts) {
    #Allow for this loop to accept multi-valued ESXiHost object as well as plain text ESXiHost
    if ($ESXiHost.Name) {$ESXiHostName = $ESXiHost.Name} else {$ESXiHostName = $ESXiHost}
    $ESXiHostShortName = $ESXiHostName.Substring(0,($ESXiHostName.IndexOf(".")))
    $ESXiOSDatastoreName = $ESXiHostShortName.ToUpper() + " (OS)"
    $ESXiHostDefaultDatastore = get-vmhost $ESXiHostName | Get-Datastore | Where-Object Name -Like "*datastore1*"
    if ($ESXiHostDefaultDatastore) {Set-Datastore -Datastore $ESXiHostDefaultDatastore -Name $ESXiOSDatastoreName}
    else {Write-Host " " ; Write-Host " No Local Datastore Found "}
}

#Configure Syslog
Foreach ($ESXiHost in $ESXiHosts) {
    Set-VMHostSysLogServer -SysLogServer $Syslog -VMHost $ESXiHost.Name
    Get-VMHostFirewallException -VMHost $ESXiHost.Name | Where-Object {$_.Name.StartsWith('syslog')} | Set-VMHostFirewallException -Enabled $true -Confirm:$false
    $esxcli = Get-EsxCli -VMHost $ESXiHost.Name
    $esxcli.system.syslog.reload()
}



#Configure default multipath policy
Foreach ($ESXiHost in $ESXiHosts) {
    $esxcli = Get-EsxCli -VMHost $ESXiHost.Name
    $esxcli.storage.nmp.satp.set($null, "VMW_PSP_RR", "VMW_SATP_ALUA")
    $esxcli.storage.nmp.satp.set($null, "VMW_PSP_RR", "VMW_SATP_DEFAULT_AA")
}

# Enter maintenance mode
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.EnterMaintenanceMode -match "Yes") { Set-VMHost -VMHost $ESXiHost.Name -State Maintenance }
}

# Join dvSwitch (NEW)
$vCenterDVSwitchObject = Get-VDSwitch -Name $vCenterDVSwitchName
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.AddToDVSwitch -match "Yes") {
        $Script:VMHostPhysicalNICsToAdd = @()
        Foreach ($VMHostPhysicalNIC in $VMHostPhysicalNICs) {
            $Script:VMHostPhysicalNICsToAdd += Get-VMHost $ESXiHost.Name | Get-VMHostNetworkAdapter -Physical -Name $VMHostPhysicalNIC
        }
        $vCenterDVPortGroupManagementObject = Get-VDPortgroup -VDSwitch $vCenterDVSwitchObject | Where-Object -Property "Name" -Match -Value $vCenterDVPortGroupManagement
        $VMHostVirtualNICManagement = Get-VMHost $ESXiHost.Name | Get-VMHostNetworkAdapter -VMKernel -Name "vmk0"
        $ESXiHostVMs = Get-VMHost -Name $ESXiHost.Name | Get-VM
        Add-VDSwitchVMHost -VDSwitch $vCenterDVSwitchObject -VMHost $ESXiHost.Name
        if ($ESXiHostVMs) {
            Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $Script:VMHostPhysicalNICsToAdd[0] -DistributedSwitch $vCenterDVSwitchObject -VirtualNicPortgroup $vCenterDVPortGroupManagementObject -VMHostVirtualNic $VMHostVirtualNICManagement -Confirm:$False
            $Script:VMHostPhysicalNICsToAdd = $Script:VMHostPhysicalNICsToAdd[1..($VMHostPhysicalNICs.Length-1)]
            Start-Sleep -Seconds 1
            $ESXiHostVMs | Get-NetworkAdapter | Set-NetworkAdapter -PortGroup $vCenterDVPortGroupManagementObject -Confirm:$False
            Start-Sleep -Seconds 1
        }
        Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $Script:VMHostPhysicalNICsToAdd -DistributedSwitch $vCenterDVSwitchObject -VirtualNicPortgroup $vCenterDVPortGroupManagementObject -VMHostVirtualNic $VMHostVirtualNICManagement -Confirm:$False
        Start-Sleep -Seconds 1
    }
}

# Remove vSwitch (NEW)
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.RemoveVSwitch -match "Yes" -and $ESXiHost.AddToDVSwitch -match "Yes") {
        Get-VMHost $ESXiHost.Name | Get-VirtualSwitch -Standard | Remove-VirtualSwitch -Confirm:$false
    }
}

# Add vMotion Adapter (NEW)
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.AddvMotionVMKernel -match "Yes") {
        $vCenterDVPortGroupvMotionObject = Get-VDSwitch | Get-VDPortgroup | Where-Object -Property "Name" -Match -Value $vCenterDVPortGroupvMotion
        New-VMHostNetworkAdapter -VMHost $ESXiHost.Name -VirtualSwitch (Get-VDSwitch) -PortGroup $vCenterDVPortGroupvMotionObject -IP $ESXiHost.vMotionIPAddress -SubnetMask $ESXiHost.vMotionSubnetMask -VMotionEnabled $true -Mtu 9000
    }
}

# Join cluster (NEW)
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.JoinCluster -match "Yes") {
        Move-VMHost -VMHost $ESXiHost.Name -Destination (Get-Cluster -Name $vCenterClusterName)
    }
}

# Change root password on hosts (NEW)
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.ChangePW -match "Yes") {
    $esxcli = get-esxcli -vmhost $ESXiHost.Name -v2
    $esxcliargs = $esxcli.system.account.set.CreateArgs() #Get Parameter list (Arguments)
    $esxcliargs.id = "root"
    $esxcliargs.password = $ESXiHost.NewPW
    $esxcliargs.passwordconfirmation = $ESXiHost.NewPW
    Write-Host ("Changing password for: " + $ESXiHost.Name)
    $esxcli.system.account.set.Invoke($esxcliargs)
    }
}

# Close connections
Disconnect-VIServer $vCenterAddress -Confirm:$False
if ($SSHSession) { Remove-SSHSession -SSHSession $SSHSession }