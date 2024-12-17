#Author: Richard Hilton
#Maintained by: Rory Marland
#Version: 0.97.5
#Purpose: Create VM in vCenter directly from template, set hardware, deploy configuration.
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher
#Last Change by: Rory Marland
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: In v0.97.1 the default portgroups were change from blackhole to quarantine.
#Changes: In v0.97.2 brought the firmware up to 9.8.4(20) 
#Changes: In v0.97.3 Added the option of an ASAv30
#Changes: In v0.97.4 brought the firmware up to 9.8.4(29) 
#Changes: In v0.97.5 brought the firmware up to 9.8.4(39) to protect against CVE-2020-3581

# -- Script Variables; change for every deployment --

#Set variables; Deployment target
$DeployToPlatform = "set me" #Options: PrivateCloud, PEC4edi3cloum2, PEC4edi3clouc3, PEC4rdg3clouc2, PEC4mkn1clouc2, PEC4mkn1clouc3
$DeployToSite = "set me" #Options: EDI3M2, EDI3C3, RDG3C2, MKN1C2, MKN1C3

# Set variables; Cisco ID Token (Licensing)
$ASAvIDToken = 'MGFkZWQ4ZWQtNDI1ZS00NjhjLTllNTktNDk1NjhmYjAxYTlmLTE2Mzk2Njk0%0ANTQ5MTN8VDVXR2RGQUd0ZnpmNkdZYUIrTkxORnc4dTJtRndXc1ZocHpmZFVR%0AaUg5ST0%3D%0A'

# Set variables; Private cloud deployment target settings
# Ignore if deploying to PEC.
$DeployToTypePrivateCloud = "Cluster"
$DeployToNamePrivateCloud = ""
$DeployTovCenterPrivateCloud = "localhost"
$DeployToResourcePoolPrivateCloud = ""
$IncludeVirtualMACsPrivateCloud = "Yes"

<# Set Variables; ASAVs to deploy
Options:
Type: ASAv5, ASAv10 or ASAv30
DeploymentType: Standalone, HAPrimary, HASecondary
Datastore: The name of the datastore to deploy the VM to
SecurePassword: The password to be set on the ASAv
DefaultGateway: The default route to be set on the ASAv
FailoverKey: The password to be set in the failover configuration
Standalone Example
$NewASAvsInput = @'
Name,Type,DeploymentType,Datastore,SecurePassword,DefaultGateway,FailoverKey
FRWL-00000001,ASAv5,Standalone,<vmfsvolume>,<password>,<DefaultGatewayIP>,<FailoverKey>
'@ | ConvertFrom-Csv
HA Pair Example
$NewASAvsInput = @'
Name,Type,DeploymentType,Datastore,SecurePassword,DefaultGateway,FailoverKey
FRWL-00000001,ASAv5,HAPrimary,<vmfsvolumename>,<password>,<DefaultGatewayIP>,<FailoverKey>
FRWL-00000002,ASAv5,HASecondary,<vmfsvolumename>,<password>,<DefaultGatewayIP>,<FailoverKey>
'@ | ConvertFrom-Csv
#>
$NewASAvsInput = @'
Name,Type,DeploymentType,Datastore,SecurePassword,DefaultGateway,FailoverKey
'@ | ConvertFrom-Csv
$NewASAvsInput | Add-Member -MemberType NoteProperty -Name "Interfaces" -Value $null

# Set variables; ASAv Interfaces
<# PEC4 ACI Default Networks:
Management: quarantine
BlackHole: quarantine
EPG: <AccountCode>|<AccountAode>-<ApplicationProfileName>|<AccountAode>-<EPGName>
eg. PROV|PROV-AP1|PROV-EPG101
Example:
$NewASAvInterfaces = @'
VMwareInterface,CiscoInterface,Portgroup,Enabled,Description,NameIf,SecurityLevel,IPAddress,SubnetMask,HA,StandbyIP,
Management0_0,Management0/0,quarantine,No,,management,,,,No,
GigabitEthernet0_0,GigabitEthernet0/0,<PortGroup1>,Yes,*** Internet Transit Interface ***,outside,0,<TransitIP>,<TransitMask>,No,
GigabitEthernet0_1,GigabitEthernet0/1,<PortGroup2>,Yes,*** Inside ***,inside,100,<InsideIP>,<InsideMask>,No,
GigabitEthernet0_2,GigabitEthernet0/2,quarantine,No,,,,,,No,
GigabitEthernet0_3,GigabitEthernet0/3,quarantine,No,,,,,,No,
GigabitEthernet0_4,GigabitEthernet0/4,quarantine,No,,,,,,No,
GigabitEthernet0_5,GigabitEthernet0/5,quarantine,No,,,,,,No,
GigabitEthernet0_6,GigabitEthernet0/6,quarantine,No,,,,,,No,
GigabitEthernet0_7,GigabitEthernet0/7,quarantine,No,,,,,,No,
GigabitEthernet0_8,GigabitEthernet0/8,quarantine,No,,,,,,No,
'@ | ConvertFrom-Csv
#>
$NewASAvInterfaces = @'
VMwareInterface,CiscoInterface,Portgroup,Enabled,Description,NameIf,SecurityLevel,IPAddress,SubnetMask,HA,StandbyIP
'@ | ConvertFrom-Csv
# Which interface should be considered as inside?
$NewASAvInsideInterfaceName = "inside"
# -- Script Variables; change only if required --
# Set variables; ASAv OVF details
$ASAvTemplateOVFName = "asav-vi.ovf"
$ASAvTemplateMFName = "asav-vi.mf"
$ASAvTemplateDay0Name = "day0.iso"
$ASAvTemplateConfigName = "day0-config"
$ASAvTemplateIDTokenName = "idtoken"
# Set variables; Paths based on deployment
switch ($DeployToPlatform) {
PrivateCloud {
$ASAvTemplatePath = "\\shared.dedipower.com\Provisioning\VM Templates\Cisco\ASAv\asav984-39"
$ASAvTempDeploymentPath = "D:\Pulsant\ASAv\"
$ProvisioningPW = Read-Host -Prompt "Enter Provisioning user password for shared.dedipower.com"
$ImgBurnPath = "\\shared.dedipower.com\Provisioning\Software\mkisofs\mkisofs.exe"
}
PEC4edi3cloum2 {
$ASAvTemplatePath = "\\piiplat.net\dfs\fileshare\VM Templates (PAT)\Cisco\ASAv\asav984-39"
$ASAvTempDeploymentPath = "Z:\Pulsant\ASAv\"
$ImgBurnPath = "Z:\Provisioning\mkisofs\mkisofs.exe"
}
PEC4edi3clouc3 {
$ASAvTemplatePath = "\\piiplat.net\dfs\fileshare\VM Templates (PAT)\Cisco\ASAv\asav984-39"
$ASAvTempDeploymentPath = "Z:\Pulsant\ASAv\"
$ImgBurnPath = "Z:\Provisioning\mkisofs\mkisofs.exe"
}
PEC4rdg3clouc2 {
$ASAvTemplatePath = "\\piiplat.net\dfs\fileshare\VM Templates (PAT)\Cisco\ASAv\asav984-39"
$ASAvTempDeploymentPath = "Z:\Pulsant\ASAv\"
$ImgBurnPath = "Z:\Provisioning\mkisofs\mkisofs.exe"
}
PEC4mkn1clouc2 {
$ASAvTemplatePath = "\\piiplat.net\dfs\fileshare\VM Templates (PAT)\Cisco\ASAv\asav984-39"
$ASAvTempDeploymentPath = "Z:\Pulsant\ASAv\"
$ImgBurnPath = "Z:\Provisioning\mkisofs\mkisofs.exe"
}
PEC4mkn1clouc3 {
$ASAvTemplatePath = "\\piiplat.net\dfs\fileshare\VM Templates (PAT)\Cisco\ASAv\asav984-39"
$ASAvTempDeploymentPath = "Z:\Pulsant\ASAv\"
$ImgBurnPath = "Z:\Provisioning\mkisofs\mkisofs.exe"
}
}






# Generate variables; Virtual MAC Addresses
$NewASAvInterfaces | Add-Member -MemberType NoteProperty -Name "ActiveMAC" -Value ""
$NewASAvInterfaces | Add-Member -MemberType NoteProperty -Name "StandbyMAC" -Value ""
$Prefix = "02"
$IPAddress = ($NewASAvInterfaces | Where-Object -Property "CiscoInterface" -match -Value "GigabitEthernet0/0").IPAddress
$Script:OctetsDecimal = {$IPaddress.Split(".")}.Invoke()
$Script:OctetsHex = {}.Invoke()
foreach ($OctetDecimal in $Script:OctetsDecimal) { $Script:OctetsHex += [Convert]::ToString($OctetDecimal, 16) }
$CiscoMac = $Prefix + $Script:OctetsHex[0] + "." + $Script:OctetsHex[1] + $Script:OctetsHex[2] + "." + $Script:OctetsHex[3]
$Script:CiscoMacSuffix = 1
$Script:Loop = 0
foreach ($NewASAvInterface in $NewASAvInterfaces) {
if ($NewASAvInterface.HA -match "Yes") {
$NewASAvInterfaces[$Script:Loop].ActiveMAC = $CiscoMac + $Script:CiscoMacSuffix.ToString("00")
$Script:CiscoMacSuffix ++
$NewASAvInterfaces[$Script:Loop].StandbyMAC = $CiscoMac + $Script:CiscoMacSuffix.ToString("00")
$Script:CiscoMacSuffix ++
}
$Script:Loop ++
}

# Generate variables; Join Interfaces to NewASAv objects
$Script:NewASAvsAndInterfaces = {}.Invoke()
$Script:Loop = 0
foreach ($NewASAvInput in $NewASAvsInput) {
$Script:NewASAvsAndInterfaces.Add($NewASAvInput)
foreach ($NewASAvInterface in $NewASAvInterfaces) {
$Script:NewASAvsAndInterfaces[$Script:Loop].Interfaces += @{($NewASAvInterface.VMwareInterface) = $NewASAvInterface}
}
$Script:Loop ++
}
$NewASAvs = $Script:NewASAvsAndInterfaces
switch ($DeployToPlatform) {
PrivateCloud {
$DeployToType = $DeployToTypePrivateCloud
$DeployTovCenter = $DeployTovCenterPrivateCloud
$ResourcePool = $DeployToResourcePoolPrivateCloud
$HDD1DiskFormat = "Thin"
$IncludeVirtualMACs = $IncludeVirtualMACsPrivateCloud
$DeployToName = $DeployToNamePrivateCloud
$ProvisioningPW = Read-Host -Prompt "Enter Provisioning user password for shared.dedipower.com"
}
PEC4edi3cloum2 {
$DeployToType = "Cluster"
switch ($DeployToSite) {
EDI3M2 { $DeployTovCenter = "edi3cloum2vct01" ; $DeployToName = "edi3cloum2"}
}
$ResourcePool = "edi3cloum2-NetworkDevices"
$HDD1DiskFormat = "Thin"
$IncludeVirtualMACs = "No"
}
PEC4edi3clouc3 {
$DeployToType = "Cluster"
switch ($DeployToSite) {
EDI3C3 { $DeployTovCenter = "edi3cloum2vct01" ; $DeployToName = "edi3clouc3"}
}
$ResourcePool = "edi3clouc3-NetworkDevices"
$HDD1DiskFormat = "Thin"
$IncludeVirtualMACs = "No"
}
PEC4rdg3clouc2 {
$DeployToType = "Cluster"
switch ($DeployToSite) {
RDG3C2 { $DeployTovCenter = "rdg3cloum2vct01" ; $DeployToName = "rdg3clouc2"}
}
$ResourcePool = "rdg3clouc2-NetworkDevices"
$HDD1DiskFormat = "Thin"
$IncludeVirtualMACs = "No"
}
PEC4mkn1clouc2 {
$DeployToType = "Cluster"
switch ($DeployToSite) {
MKN1C2 { $DeployTovCenter = "mkn1clouc2vct01" ; $DeployToName = "mkn1clouc2"}
}
$ResourcePool = "mkn1clouc2-NetworkDevices"
$HDD1DiskFormat = "Thin"
$IncludeVirtualMACs = "No"
}
PEC4mkn1clouc3 {
$DeployToType = "Cluster"
switch ($DeployToSite) {
MKN1C3 { $DeployTovCenter = "mkn1clouc2vct01" ; $DeployToName = "mkn1clouc3"}
}
$ResourcePool = "mkn1clouc3-NetworkDevices"
$HDD1DiskFormat = "Thin"
$IncludeVirtualMACs = "No"
}
}
# Set names of the parameters in the ASAv Config. Shouldn't need to update this, but is present
$ASAvConfigParameterNames = @{
Hostname = "<hostname>"
SecurePassword = "<securepassword>"
OutsideIP = "<outsideip>"
OutsideMask = "<outsidemask>"
DefaultGateway = "<defaultgateway>"
InsideName = "inside"
InsideIP = "<insideip>"
InsideMask = "<insidemask>"
NTPServer = "<ntpserver>"
ReadingDNS = "!RDGDNS"
DefaultDNS = "!DEFAULTDNS"
FailoverKey = "<FAILOVER_KEY>"
InterfaceConfig = "<interfaceconfig>"
MonitorInterfaceConfig = "<monitorinterfaceconfig>"
}
#region ASAv Configuration Template
# Set ASAv Config - do not change the <parameters> in the script, these are set by the script from CSV input. Other parts of the config can be changed however.
$ASAvsConfig = @'
!Changes required - use search/replace to update the following labels.
!-------------------------------------------------------------------------------
!<hostname> FRWL-XXXXX-<descriptor>
!<securepassword> for root and enable
!< interfaceconfig > is inserted by the powershell script (without spaces)
!<defaultgateway> the default gateway address
!<ntpserver> use RDG1-NTP1, EDI1-NTP1 or MKN1-NTP1 as appropriate for the device location
!
!Search and replace the following text, replacing with blank, to set the appropriate DNS servers
!For Reading hosted devices !RDGDNS
!For all other devices !DEFAULTDNS
!-------------------------------------------------------------------------------
hostname <hostname>
!
domain-name service.pulsant.com
!
ssl encryption 3des-sha1 aes128-sha1 aes256-sha1 rc4-sha1 rc4-md5
!
<interfaceconfig>
!
enable password <securepassword>
username pulsant password <securepassword> privilege 15
aaa authentication ssh console LOCAL
!
names
name 81.29.64.26 RDG1-Office description Reading Office Access
name 81.29.64.245 RDG1-Monitor description Reading Objects Monitoring Server
name 81.29.64.227 RDG1-Charly description MIST Ping Monitoring
name 81.29.64.238 RDG1-NODAV description NOD32 AntiVirus Server
name 81.29.66.3 RDG1-Bright description DNS Lookup
name 89.151.127.9 RDG1-Cacti description Dedipower Cacti Access
name 217.30.126.10 EDI1-Office description Newbridge Office Access
name 217.30.126.64 EDI1-Office2 description Newbridge Office Public IP subnet
name 87.246.83.202 EDI1-cpesyslog-01 description Newbridge CPE syslog server
name 212.20.231.66 EDI1-Mon1 description Newbridge monitoring server 1
name 212.20.231.84 EDI1-Mon2 description Newbridge monitoring server 2
name 212.20.231.71 EDI1-Syslog description Newbridge infrastructure syslog server
name 212.20.226.2 EDI1-Quantz description Clusteradmin server 1
name 212.20.226.10 EDI1-Paganini description Clusteradmin server 2
name 212.20.226.229 EDI1-NTP1 description Newbridge NTP server 1
name 212.20.226.134 MKN1-NTP1 description Milton Keynes NTP server 1
name 87.246.122.110 EDI3-Office description South Gyle Office Access
name 81.29.64.60 RDG1-RNS description Cadogan House Resolving Name Server
name 89.151.64.70 RDG2-RNS description TVHC1 Resolving Name Server
name 89.151.64.212 RDG1-SIM1 description Cadogan House HP SIM Server
name 81.29.64.237 RDG1-NTP1 description Cadogen House NTP Server
name 46.236.30.90 RDG3-SERV-ORN1 description Reading Orion Poller
name 46.249.207.90 EDI3-SERV-ORN1 description South Gyle Orion Poller
name 46.236.30.85 RDG3-SERV-LOG1 description Reading Syslog collector
name 46.249.219.85 MKN1-SERV-LOG1 description Milton Keynes Syslog collector
name 46.249.207.85 EDI3-SERV-LOG1 description South Gyle Syslog collector
name 89.151.73.128 PIIP-RDG3 description Pulsant Service V2 Reading
name 195.97.223.0 PIIP-Onyx description Pulsant Service V2 Onyx
name 217.30.120.64 PIIP-EDI3 description Pulsant Service V2 Edinburgh
!
clock timezone GMT 0
clock summer-time BST recurring last Sun Mar 1:00 last Sun Oct 2:00
dns domain-lookup outside
!
ntp server <ntpserver> source outside prefer
!
!RDGDNS dns name-server RDG1-RNS
!RDGDNS dns name-server RDG2-RNS
!DEFAULTDNS dns server-group DefaultDNS
!DEFAULTDNS name-server 212.20.226.130
!DEFAULTDNS name-server 212.20.226.194
!DEFAULTDNS name-server 212.20.226.131
!DEFAULTDNS name-server 69.164.211.183
!
http server enable
http 0.0.0.0 0.0.0.0 inside
http RDG1-Office 255.255.255.255 outside
http EDI1-Office 255.255.255.255 outside
http EDI1-Office2 255.255.255.192 outside
http EDI3-Office 255.255.255.255 outside
http PIIP-RDG3 255.255.255.224 outside
http PIIP-Onyx 255.255.255.224 outside
http PIIP-EDI3 255.255.255.224 outside
!
ssh 0.0.0.0 0.0.0.0 inside
ssh RDG1-Office 255.255.255.255 outside
ssh EDI1-Office 255.255.255.255 outside
ssh EDI1-Office2 255.255.255.192 outside
ssh 46.236.30.90 255.255.255.255 outside
ssh 46.249.207.90 255.255.255.255 outside
ssh EDI3-Office 255.255.255.255 outside
ssh PIIP-RDG3 255.255.255.224 outside
ssh PIIP-Onyx 255.255.255.224 outside
ssh PIIP-EDI3 255.255.255.224 outside
!
ssh timeout 5
ssh version 2
console timeout 2
telnet timeout 5
!
logging enable
logging buffer-size 40960
logging asdm-buffer-size 512
logging buffered notifications
logging trap notifications
logging asdm debugging
logging facility 16
logging device-id hostname
logging host outside EDI1-cpesyslog-01
!
same-security-traffic permit inter-interface
same-security-traffic permit intra-interface
object-group service Web tcp
port-object eq www
port-object eq https
object-group service FTP tcp
port-object eq ftp
port-object eq ftp-data
object-group service RDP tcp
port-object eq 3389
object-group service SSH tcp
port-object eq ssh
object-group service Mail tcp
port-object eq imap4
port-object eq pop3
port-object eq smtp
object-group service CDPBackups tcp
port-object eq 1167
object-group service Plesk tcp
port-object eq 8443
port-object eq 11444
object-group service cPanel tcp
port-object eq 2082
Port-object eq 2083
port-object eq 2086
port-object eq 2087
object-group service NTP tcp
port-object eq 123
object-group service HP tcp
description HP web hardware access
port-object eq 2381
object-group service Dell tcp
description Openmanage web access
port-object eq 1311
object-group service DNS tcp-udp
port-object eq domain
object-group protocol TCPUDP
protocol-object udp
protocol-object tcp
object-group icmp-type Traceroute
icmp-object echo-reply
icmp-object time-exceeded
object-group network RDG1-CDPServers
network-object 81.29.95.32 255.255.255.240
network-object 89.151.65.0 255.255.255.192
network-object host 202.170.0.72
object-group network RDG1-AVServers
network-object RDG1-NODAV 255.255.255.255
object-group network RDG1-SupportServers
network-object RDG1-Charly 255.255.255.255
network-object RDG1-Monitor 255.255.255.255
network-object RDG1-Cacti 255.255.255.255
network-object RDG1-SIM1 255.255.255.255
object-group network RDG1-SupportAccess
network-object RDG1-Office 255.255.255.255
object-group service Public tcp
group-object Web
!
object network EDI1-OfficePublicLan
subnet 217.30.126.64 255.255.255.192
!
object network NBG01-CACTI-02
host 212.20.231.99
!
object network NBG01-CACTI-03
host 212.20.231.100
!
object-group network EDI1-SupportServers
network-object EDI1-Office 255.255.255.255
network-object EDI1-Office2 255.255.255.192
network-object EDI1-cpesyslog-01 255.255.255.255
network-object EDI1-Mon1 255.255.255.255
network-object EDI1-Mon2 255.255.255.255
network-object EDI1-Syslog 255.255.255.255
network-object EDI1-Quantz 255.255.255.255
network-object EDI1-Paganini 255.255.255.255
network-object EDI1-NTP1 255.255.255.255
network-object MKN1-NTP1 255.255.255.255
!
object-group network EDI3-SupportServers
network-object EDI3-Office 255.255.255.255
!
object network RDG1-ManagementServers
description Reading: Monitoring and Management Services
subnet 46.236.30.80 255.255.255.240
!
object-group network CACTI-SERVERS
network-object object NBG01-CACTI-02
network-object object NBG01-CACTI-03
!
object-group network Pulsant-ManagementServers
group-object CACTI-SERVERS
!
object-group network Pulsant-ManagementServers
description Monitoring and Management Services
network-object object RDG1-ManagementServers
!
object-group network AllOrionPollers
description All Orion polling engines
network-object host 46.236.30.90
network-object host 46.249.207.90
!
object network PIIP-RDG3
subnet 89.151.73.128 255.255.255.224
object network PIIP-Onyx
subnet 195.97.223.0 255.255.255.224
object network PIIP-EDI3
subnet 217.30.120.64 255.255.255.224
!
object-group network Pulsant-ManagementAccess
network-object object PIIP-EDI3
network-object object PIIP-Onyx
network-object object PIIP-RDG3
!
access-list outside_access_in remark Permit Pulsant-ManagementAccess to any
access-list outside_access_in extended permit ip object-group Pulsant-ManagementAccess any
access-list outside_access_in remark Permit RDG1-CDPBackups
access-list outside_access_in extended permit tcp object-group RDG1-CDPServers any object-group CDPBackups
access-list outside_access_in remark Permit RDG1-Anti-virus server access
access-list outside_access_in extended permit ip object-group RDG1-AVServers any
access-list outside_access_in remark Permit RDG1-SupportAccess to any
access-list outside_access_in extended permit ip object-group RDG1-SupportAccess any
access-list outside_access_in remark Permit RDG1-SupportServer to any
access-list outside_access_in extended permit ip object-group RDG1-SupportServers any
access-list outside_access_in remark Permit EDI1-SupportServers to any
access-list outside_access_in extended permit ip object-group EDI1-SupportServers any
access-list outside_access_in remark Permit EDI3-SupportServers to any
access-list outside_access_in extended permit ip object-group EDI3-SupportServers any
access-list outside_access_in remark Permit Pulsant-ManagementServers to any
access-list outside_access_in extended permit ip object-group Pulsant-ManagementServers any
access-list outside_access_in extended permit ip object-group AllOrionPollers any
!
access-group outside_access_in in interface outside
!
arp permit-nonconnected
!
route outside 0.0.0.0 0.0.0.0 <defaultgateway> 1
!
priority-queue inside
priority-queue outside
!
class-map qos2
match precedence 5
class-map inspection_default
match default-inspection-traffic
class-map qos
match dscp ef
!
policy-map qos-policy
class qos
priority
class qos2
priority
!
policy-map type inspect dns preset_dns_map
parameters
message-length maximum client auto
message-length maximum 512
dns-guard
protocol-enforcement
nat-rewrite
!
policy-map global_policy
class inspection_default
inspect icmp
inspect dns preset_dns_map
inspect ftp
inspect h323 h225
inspect h323 ras
inspect ip-options
inspect netbios
inspect rsh
inspect rtsp
inspect skinny
inspect sqlnet
inspect sunrpc
inspect tftp
inspect sip
inspect xdmcp
!
service-policy global_policy global
!
snmp-server host outside 46.236.30.90 community E5iqcCfp version 2c
snmp-server host outside 46.249.207.90 community E5iqcCfp version 2c
snmp-server host outside 212.20.231.99 poll community rw01Kw08 version 2c
snmp-server host outside 212.20.231.100 poll community rw01Kw08 version 2c
no snmp-server location
snmp-server contact support@pulsant.com
snmp-server community RJ2ZjpCd
snmp-server enable traps snmp authentication linkup linkdown coldstart
!
icmp unreachable rate-limit 1 burst-size 1
icmp permit any inside
icmp permit any outside
!
banner login ********************************************************************************
banner login ********************************************************************************
banner login ** WARNING **
banner login ** ******* **
banner login ** **
banner login ** This is a PRIVATE RESTRICTED access system. **
banner login ** **
banner login ** Disconnect NOW if you have not been expressly authorised to use this **
banner login ** system. Unauthorised use is a criminal offence under the **
banner login ** Computer Misuse Act 1990. **
banner login ** **
banner login ** You are reminded that all access is logged. **
banner login ** **
banner login ** Communications on or through Pulsant computer systems may be logged, **
banner login ** monitored or recorded to secure effective system operation and for other **
banner login ** lawful and evidential purposes. **
banner login ** **
banner login ** Unauthorised users will be prosecuted to the fullest extent of the law. **
banner login ** **
banner login ** By continuing, you consent to your session, keystrokes and data content **
banner login ** being logged and monitored for lawful and evidential purposes. **
banner login ** **
banner login ********************************************************************************
banner login ********************************************************************************
!
banner motd ********************************************************************************
banner motd ********************************************************************************
banner motd ** NOTE: This device is subject to FULL change control procedures **
banner motd ** **
banner motd ** Please follow account notes and customer documentation **
banner motd ** **
banner motd ** REQUIRES CUSTOMER AUTHORISATION FOR ANY CHANGES **
banner motd ** **
banner motd ** Please ensure that documentation and MIST are updated following any change **
banner motd ** **
banner motd ********************************************************************************
banner motd ********************************************************************************
banner motd
!
crypto key generate rsa modulus 1024 noconfirm
!
'@
$ASAvsConfigHAPrimary = @'
!
! Failover - Primary Unit
! -----------------------
!
failover
failover lan unit primary
failover lan interface failover GigabitEthernet0/8
failover polltime unit 3 holdtime 10
failover key <FAILOVER_KEY>
failover interface ip failover 169.254.99.1 255.255.255.252 standby 169.254.99.2
!
! Enable stateful failover - Add to all models except 5505 and 5512X.
failover link failover
!
!
interface GigabitEthernet0/8
no shutdown
!
!Update the prompt for simpler debug
prompt hostname state priority
!
<monitorinterfaceconfig>
!
'@
$ASAvsConfigHASecondary = @'
! Failover - Secondary Unit
! -------------------------
failover
failover lan unit secondary
failover lan interface failover GigabitEthernet0/8
failover polltime unit 3 holdtime 10
failover key <FAILOVER_KEY>
failover interface ip failover 169.254.99.1 255.255.255.252 standby 169.254.99.2
! Enable stateful failover - Add to all models except 5505 and 5512X.
failover link failover
interface GigabitEthernet0/8
no shutdown
'@
$ASAv5Config = @'
license smart
feature tier standard
throughput level 100M
'@
$ASAv10Config = @'
license smart
feature tier standard
throughput level 1G
'@
$ASAv30Config = @'
license smart
feature tier standard
throughput level 2G
'@
#endregion
# -- Open connections --
#Initialize PowerCLI
#. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
#. "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true
#Connect to vCenter
if (!$vCenterConnection) { $vCenterConnection = Connect-VIServer -Server $DeployTovCenter -Force -ErrorAction Stop }
elseif ($vCenterConnection.IsConnected -ne $true -or $vCenterConnection.Name -notlike $DeployTovCenter) { $vCenterConnection = Connect-VIServer -Server $DeployTovCenter -Force -ErrorAction Stop }
# Open connection to shared.dedipower.com if required
switch ($DeployToPlatform) {
PrivateCloud { net use \\shared.dedipower.com\Provisioning /USER:provisioning /Persistent:no $ProvisioningPW }
}

# -- Verfication section --
Write-Host ; Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host
# Initialize error counter
$Script:ErrorCount = 0
# Check paths
# Deployment Temp Path
$null = md $ASAvTempDeploymentPath -ErrorAction SilentlyContinue
if (!(Test-Path $ASAvTempDeploymentPath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access temporary deployment path $ASAvTempDeploymentPath }
# ASAv Template files
if (!(Test-Path $ASAvTemplatePath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access ASAv template path $ASAvTemplatePath }
if (!(Test-Path ($ASAvTemplatePath + "\" + $ASAvTemplateOVFName) -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access ASAv OVF file $ASAvTemplatePath\$ASAvTemplateOVFName }
if (!(Test-Path ($ASAvTemplatePath + "\" + $ASAvTemplateMFName) -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access ASAv MF file $ASAvTemplatePath\$ASAvTemplateMFName }
if (!(Test-Path ($ASAvTemplatePath + "\" + $ASAvTemplateDay0Name) -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access ASAv Day0 ISO file $ASAvTemplatePath\$ASAvTemplateDay0Name }
# mkisofs (Refresh mkisofs if found)
if (!(Test-Path $ImgBurnPath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access mkisofs at $ImgBurnPath }
else {(Get-Item $ImgBurnPath).CreationTime = Get-Date}

# Check vCenter is Connected (future)

# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding to deploy VMs." ; Write-Host }

# -- Script actions start here --
# Copy template to temp folder, and build day0 config
foreach ($NewASAv in $NewASAvs) {
# Create temp folder based on firewall name
$ASAvTempFolder = $ASAvTempDeploymentPath + $NewASAv.Name + "\"
md $ASAvTempFolder
# Copy ASAv Source files to temp folder
$ASAvCopySource = $ASAvTemplatePath + "\*.*"
Copy-Item $ASAvCopySource $ASAvTempFolder -Recurse
# Rename exsiting Day0 ISO
$ASAvTempDay0ISOExistingName = "day0existing.iso"
Rename-Item $ASAvTempFolder$ASAvTemplateDay0Name $ASAvTempFolder$ASAvTempDay0ISOExistingName
# Get existing Day0 ISO file hash and length
$ASAvTempDay0ISOExistingHash = (Get-FileHash -Path $ASAvTempFolder$ASAvTempDay0ISOExistingName -Algorithm SHA1).Hash.ToLower()
$ASAvTempDay0ISOExistingLength = (Get-Item -Path $ASAvTempFolder$ASAvTempDay0ISOExistingName).Length
# Get existing ovf file hash
$ASAvTempOVFExistingHash = (Get-FileHash -Path $ASAvTempFolder$ASAvTemplateOVFName -Algorithm SHA1).Hash.ToLower()

# Build OVF Day0 Config
# Set Site-based Variables
switch ($DeployToSite) {
RDG3C2 {
$NewASAvConfigNTPServer = "RDG1-NTP1"
$ASAvConfigDNSServer = "!RDGDNS"
}
MKN1C2 {
$NewASAvConfigNTPServer = "MKN1-NTP1"
$ASAvConfigDNSServer = "!DEFAULTDNS"
}
MKN1C3 {
$NewASAvConfigNTPServer = "MKN1-NTP1"
$ASAvConfigDNSServer = "!DEFAULTDNS"
}
EDI3M2 {
$NewASAvConfigNTPServer = "MKN1-NTP1"
$ASAvConfigDNSServer = "!DEFAULTDNS"
}
EDI3C3 {
$NewASAvConfigNTPServer = "MKN1-NTP1"
$ASAvConfigDNSServer = "!DEFAULTDNS"
}
}
# Build interface configuration
$Script:NewASAvInterfaceConfig = ""
$Script:NewASAvMonitorInterfaceConfig = ""
$CR = [char]13 ; $LF = [char]10 ; [string]$CRLF = $CR + $LF
foreach ($NewASAvInterface in $NewASAvInterfaces) {
$Script:NewASAvInterfaceConfig += "interface " + $NewASAvInterface.CiscoInterface + $CRLF
if ($NewASAvInterface.Description) {$Script:NewASAvInterfaceConfig += " description " + $NewASAvInterface.Description + $CRLF}
switch ($NewASAvInterface.Enabled) {
Yes {
$Script:NewASAvInterfaceConfig += " nameif " + $NewASAvInterface.NameIf + $CRLF
$Script:NewASAvInterfaceConfig += " security-level " + $NewASAvInterface.SecurityLevel + $CRLF
if ($NewASAvInterface.HA -match "Yes") {
$Script:NewASAvInterfaceConfig += " ip address " + $NewASAvInterface.IPAddress + " " + $NewASAvInterface.SubnetMask + `
" standby " + $NewASAvInterface.StandbyIP + $CRLF
if ($IncludeVirtualMACs -match "Yes") {
$Script:NewASAvInterfaceConfig += " mac-address " + $NewASAvInterface.ActiveMAC + " standby " + $NewASAvInterface.StandbyMAC + $CRLF
}
$Script:NewASAvMonitorInterfaceConfig += " monitor-interface " + $NewASAvInterface.NameIf + $CRLF
}
else {$Script:NewASAvInterfaceConfig += " ip address " + $NewASAvInterface.IPAddress + " " + $NewASAvInterface.SubnetMask + $CRLF}
}
No {
$Script:NewASAvInterfaceConfig += " shutdown " + $CRLF + " no nameif" + $CRLF + " no security-level" + $CRLF + " no ip address" + $CRLF
}
}
$Script:NewASAvInterfaceConfig += $CRLF
}
$Script:NewASAvInterfaceConfig

# Replace variables in configuration
switch ($NewASAv.DeploymentType) {
Standalone {
$NewASAvConfig = -join $CRLF, $ASAvsConfig
#$NewASAvConfig = $ASAvsConfig
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InsideName , $NewASAvInsideInterfaceName
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.Hostname , $NewASAv.Name
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InterfaceConfig , $Script:NewASAvInterfaceConfig
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.SecurePassword , $NewASAv.SecurePassword
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.OutsideIP , $NewASAv.OutsideIP
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.OutsideMask , $NewASAv.OutsideMask
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.DefaultGateway , $NewASAv.DefaultGateway
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InsideIP , $NewASAv.InsideIP
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InsideMask , $NewASAv.InsideMask
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.NTPServer , $NewASAvConfigNTPServer
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigDNSServer , ""
}
HAPrimary {
$NewASAvConfig = -join $CRLF, $ASAvsConfig
#$NewASAvConfig = $ASAvsConfig
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InsideName , $NewASAvInsideInterfaceName
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.Hostname , $NewASAv.Name
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InterfaceConfig , $Script:NewASAvInterfaceConfig
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.SecurePassword , $NewASAv.SecurePassword
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.OutsideIP , $NewASAv.OutsideIP
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.OutsideMask , $NewASAv.OutsideMask
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.DefaultGateway , $NewASAv.DefaultGateway
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InsideIP , $NewASAv.InsideIP
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.InsideMask , $NewASAv.InsideMask
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.NTPServer , $NewASAvConfigNTPServer
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigDNSServer , ""
$NewASAvConfigHAPrimary = $ASAvsConfigHAPrimary
$NewASAvConfigHAPrimary = $NewASAvConfigHAPrimary -replace $ASAvConfigParameterNames.FailoverKey , $NewASAv.FailoverKey
$NewASAvConfigHAPrimary = $NewASAvConfigHAPrimary -replace $ASAvConfigParameterNames.MonitorInterfaceConfig , $Script:NewASAvMonitorInterfaceConfig
$NewASAvConfig = -join $NewASAvConfig, $NewASAvConfigHAPrimary
}
HASecondary {
$NewASAvConfig = -join $CRLF, $ASAvsConfigHASecondary
$NewASAvConfig = $NewASAvConfig -replace $ASAvConfigParameterNames.FailoverKey , $NewASAv.FailoverKey
}
}
switch ($NewASAv.Type) {
ASAv5 { $NewASAvConfig = -join $NewASAvConfig, $ASAv5Config }
ASAv10 { $NewASAvConfig = -join $NewASAvConfig, $ASAv10Config }
ASAv30 { $NewASAvConfig = -join $NewASAvConfig, $ASAv30Config }
}
# Write ASAv config & idtoken to file
$NewASAvConfig | Out-File $ASAvTempFolder$ASAvTemplateConfigName -Encoding utf8
$ASAvIDToken | Out-File $ASAvTempFolder$ASAvTemplateIDTokenName -Encoding ascii
$ASAvTemplateConfigName
# Create Day0 ISO
$ImgBurnArgs = "-iso-level 4 -o `"$ASAvTemplateDay0Name`" `"$ASAvTemplateConfigName`" `"$ASAvTemplateIDTokenName`""
Start-Process -Wait -FilePath $ImgBurnPath -ArgumentList $ImgBurnArgs -WorkingDirectory $ASAvTempFolder -ErrorAction SilentlyContinue
# Get content of OVF file
$ASAvTempOVF = $ASAvTempFolder + $ASAvTemplateOVFName
Get-Content $ASAvTempOVF | findstr $ASAvTempDay0ISOExistingHash
# Get new SHA1 hash and length of day0.iso
$ASAvTempDay0ISONewHash = (Get-FileHash -Path $ASAvTempFolder$ASAvTemplateDay0Name -Algorithm SHA1).Hash.ToLower()
$ASAvTempDay0ISONewLength = (Get-Item -Path $ASAvTempFolder$ASAvTemplateDay0Name).Length
# Update Length in OVF file
$ASAvTempOVFContent = Get-Content $ASAvTempFolder$ASAvTemplateOVFName -Raw
$ASAvTempOVFContent = $ASAvTempOVFContent -replace $ASAvTempDay0ISOExistingLength , $ASAvTempDay0ISONewLength
Set-Content -Path $ASAvTempFolder$ASAvTemplateOVFName -Value $ASAvTempOVFContent -Encoding UTF8
# Get new SHA1 hash of ovf file
$ASAvTempOVFNewHash = (Get-FileHash -Path $ASAvTempFolder$ASAvTemplateOVFName -Algorithm SHA1).Hash.ToLower()

# Update SHA1 hashes in MF file
$ASAvTempMFContent = Get-Content $ASAvTempFolder$ASAvTemplateMFName -Raw
$ASAvTempMFContent = $ASAvTempMFContent -replace $ASAvTempDay0ISOExistingHash , $ASAvTempDay0ISONewHash
$ASAvTempMFContent = $ASAvTempMFContent -replace $ASAvTempOVFExistingHash , $ASAvTempOVFNewHash
Set-Content -Path $ASAvTempFolder$ASAvTemplateMFName -Value $ASAvTempMFContent -Encoding UTF8
}
# Create New ASAvs
Foreach ($NewASAv in $NewASAvs) {
# Set ASAv Template Path
$ASAvTempFolder = $ASAvTempDeploymentPath + $NewASAv.Name + "\"
$ASAvTempOVF = $ASAvTempFolder + $ASAvTemplateOVFName
# Get Deploy Target
Switch ($DeployToType) {
Cluster {$DeployToObject = Get-Cluster $DeployToName | Get-VMHost | Where {$_.PowerState –eq "PoweredOn" –and $_.ConnectionState –eq "Connected"} | Get-Random}
Host {$DeployToObject = Get-VMHost $DeployToName}
}
# Get Datastore
$NewASAvDatastore = Get-Datastore | Where-Object {$_.Name -like $NewASAv.Datastore}
# Get Resource Pool
$NewASAvResourcePool = Get-ResourcePool $ResourcePool -ErrorAction SilentlyContinue
if (!($NewASAvResourcePool)) {Write-Host "Resource pool not found" ; $NewASAvResourcePool = $DeployToObject}
# Get ASAv OVF Configuration Template
$NewASAvConfiguration = Get-OvfConfiguration $ASAvTempOVF
# Build ASAv OVF Configuration
$NewASAvConfiguration.DeploymentOption.Value = $NewASAv.Type
$NewASAvConfiguration.Common.HARole.Value = "Standalone"
$NewASAvConfiguration.NetworkMapping.Management0_0.Value = $NewASAv.Interfaces.Management0_0.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_0.Value = $NewASAv.Interfaces.GigabitEthernet0_0.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_1.Value = $NewASAv.Interfaces.GigabitEthernet0_1.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_2.Value = $NewASAv.Interfaces.GigabitEthernet0_2.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_3.Value = $NewASAv.Interfaces.GigabitEthernet0_3.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_4.Value = $NewASAv.Interfaces.GigabitEthernet0_4.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_5.Value = $NewASAv.Interfaces.GigabitEthernet0_5.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_6.Value = $NewASAv.Interfaces.GigabitEthernet0_6.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_7.Value = $NewASAv.Interfaces.GigabitEthernet0_7.Portgroup
$NewASAvConfiguration.NetworkMapping.GigabitEthernet0_8.Value = $NewASAv.Interfaces.GigabitEthernet0_8.Portgroup
# Deploy ASAv
Import-VApp -Source $ASAvTempOVF -Datastore $NewASAvDatastore -DiskStorageFormat $HDD1DiskFormat -VMHost $DeployToObject -Name $NewASAv.Name -ErrorAction Stop -OvfConfiguration $NewASAvConfiguration -Location $NewASAvResourcePool
# Disable unused interfaces
Get-VM $NewASAv.Name | Get-NetworkAdapter | Where-Object {$_.NetworkName -match "BlackHole" -or $_.NetworkName -match "quarantine"} | Set-NetworkAdapter -StartConnected $False -Confirm:$False
# Cleanup
$DeployedSuffix = "-Deployed"
Remove-Item ($ASAvTempFolder.Substring(0,$ASAvTempFolder.Length-1) + $DeployedSuffix) -Recurse -ErrorAction SilentlyContinue
Rename-Item $ASAvTempFolder ($NewASAv.Name + $DeployedSuffix)
}
# Close Connections
switch ($DeployToPlatform) {
PrivateCloud { net use \\shared.dedipower.com\Provisioning /delete }
}
