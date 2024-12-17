## Author: James White
## Version: 0.2
## Creation date: 21/09/2020 
## Purpose: Create an external network in vCloud Director
## Dependencies: PowerShell Version 4 or higher, VMware PowerCli and network access to vCenter
## Prequisities: You must have created a VDC and vApp(s) before running the script

# Last Change by: James White
# Status: New
# Recommended Run Mode: PowerShell prompt
# Changes: Initial build
# Adjustments Required: add Parameter binding

<#
.SYNOPSIS
New-ExternalNetwork creates a new external network on the Pulsant Enterprise Cloud Platform (PEC).
.DESCRIPTION 
New-ExternalNetwork uses VMware PowerCli and the vCloud API to create a new external network in vCloud, adding it to your VDC and all vApps in that VDC
.PARAMETER accountcode
The account code of the customer in MIST
.PARAMETER orgvdc
The name of the Organisation Virtual Datacenter in which the network should be added to
.PARAMETER apnumber
The Application Profile number from ACI
.PARAMETER epgnumber
The Endpoint Group number from ACI
.PARAMETER nameif
The name of the firewall interface e.g. DMZ
.PARAMETER Gateway
The default gateway of the network
.PARAMETER Netmask
The subnet mask of the network
.PARAMETER iprangestartaddress
The start of the IP range to allocate to VMs
.PARAMETER iprangeendaddress
The end of the IP range to allocate to VMs
.EXAMPLE
.\New-ExternalNetwork.ps1 -accountcode PROV -vCSName mkn1clouc2vct01 -orgvdc 'PROV mkn1clouc2 VDC1' -apnumber 1 -epgnumber 101 -nameif DMZ -Gateway 172.22.102.1 -Netmask 255.255.255.0 -iprangestartaddress 172.22.102.10 -iprangeendaddress 172.22.102.100
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Enter a customer account code from MIST")]
    [string]$accountcode,
    [Parameter(Mandatory=$True,HelpMessage="Enter the name of the vCenter in which the port group exists")]
    [ValidateSet('mkn1clouc2vct01','edi3cloum2vct01','rdg3cloum2vct01')]
    [string]$vCSName,
    [Parameter(Mandatory=$True,HelpMessage="Enter the OrgVDC name from vCloud")]
    [string]$orgvdc,
    [Parameter(Mandatory=$True,HelpMessage="Enter the Application Profile number from ACI")]
    [string]$apnumber,
    [Parameter(Mandatory=$True,HelpMessage="Enter the Endpoint group number from ACI")]
    [string]$epgnumber,
    [Parameter(Mandatory=$True,HelpMessage="Enter The name of the firewall interface e.g. DMZ")]
    [string]$nameif,
    [Parameter(Mandatory=$True,HelpMessage="Enter the default gateway of the network")]
    [string]$Gateway,
    [Parameter(Mandatory=$True,HelpMessage="Enter the subnet of the network")]
    [string]$Netmask,
    [Parameter(Mandatory=$True,HelpMessage="Enter the start of the IP range")]
    [string]$iprangestartaddress,
    [Parameter(Mandatory=$True,HelpMessage="Enter the end of the IP range")]
    [string]$iprangeendaddress
)
## -- Script actions start here -- ##
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"
Write-Host -ForegroundColor Yellow "Connecting to Pulsant Enterprise Cloud..."
Connect-CIServer -Server cloud.pulsant.com -Credential $vCloudCredential
Write-Host -ForegroundColor Yellow "Connecting to vCenter..."
Connect-VIServer -Server $vCSName


Write-Host -ForegroundColor Yellow "Adding external network...."
$dvPG = "$accountcode|$accountcode-AP$apnumber|$accountcode-EPG$epgnumber" 
$vcloud = $DefaultCIServers[0].ExtensionData
$admin = $vcloud.GetAdmin()
$ext = $admin.GetExtension()

$mynetwork = new-object vmware.vimautomation.cloud.views.VMWExternalNetwork
$mynetwork.Name = "$accountcode|$accountcode-AP$apnumber|$accountcode-EPG$epgnumber|$vCSName"

$vCenter = Search-Cloud VirtualCenter | Get-CIView | where {$_.name -eq $vCSName}
$dvpg = get-view -viewtype DistributedVirtualPortGroup | where {$_.name -like $dvPG}

write-host "vCenter href: "$vCenter.href
write-host "dvPG Key: " $dvPG.key

$mynetwork.VimPortGroupRef = new-object VMware.VimAutomation.Cloud.Views.VimObjectRef1

$mynetwork.VimPortGroupRef.MoRef = $dvPG.key
$mynetwork.VimPortGroupRef.VimObjectType = "DV_PORTGROUP"

$mynetwork.VimPortGroupRef.VimServerRef = new-object VMware.VimAutomation.Cloud.Views.Reference
$mynetwork.VimPortGroupRef.VimServerRef.href = $vCenter.href

$mynetwork.Configuration = new-object VMware.VimAutomation.Cloud.Views.NetworkConfiguration
$mynetwork.configuration.fencemode = "isolated" 

$mynetwork.Configuration.IpScopes = new-object VMware.VimAutomation.Cloud.Views.IpScopes
$mynetwork.Configuration.IpScopes.IpScope = new-object VMware.VimAutomation.Cloud.Views.IpScope
$mynetwork.Configuration.IpScopes.ipscope[0].Gateway = "$Gateway"
$mynetwork.Configuration.IpScopes.ipscope[0].Netmask = "$Netmask"
$mynetwork.Configuration.IpScopes.ipscope[0].IsInherited = "False"
$mynetwork.Configuration.IpScopes.ipscope[0].Dns1 = "212.20.226.130"
$mynetwork.Configuration.IpScopes.ipscope[0].Dns2 = "212.20.226.194"

$mynetwork.Configuration.IpScopes.ipscope[0].ipranges = new-object vmware.vimautomation.cloud.views.ipranges
$mynetwork.Configuration.Ipscopes.ipscope[0].ipranges.iprange = new-object vmware.vimautomation.cloud.views.iprange
$mynetwork.Configuration.IpScopes.ipscope[0].IpRanges.IpRange[0].startaddress = "$iprangestartaddress"
$mynetwork.Configuration.IpScopes.ipscope[0].IpRanges.IpRange[0].endaddress = "$iprangeendaddress"

$result = $ext.CreateExternalNet($mynetwork)

$result

Write-Host -ForegroundColor Yellow "Adding external network to OrgVDC..."
New-OrgVdcNetwork -Direct -Name "$accountcode-EPG$epgnumber|$nameif" -Org $orgvdc -ExternalNetwork "$accountcode|$accountcode-AP$apnumber|$accountcode-EPG$epgnumber|$vCSName"

Write-Host -ForegroundColor Yellow "Attaching the external network to all vApps in the VDC"
$vapps = (Get-CIVApp -OrgVdc $orgvdc)
ForEach ($vapp in $vapps) {
New-CIVAppNetwork -ParentOrgVdcNetwork "$accountcode-EPG$epgnumber|$nameif" -VApp $vapp -Direct
}

## -- Close Connections -- ##
Write-Host -ForegroundColor Green "Script complete, closing connections and removing variables from memory"
Disconnect-CIServer -Server cloud.pulsant.com -Confirm:$false
Remove-Variable vCSName,accountcode,orgvdc,apnumber,epgnumber,nameif,Gateway,Netmask,iprangestartaddress,iprangeendaddress,vapp,vapps,mynetwork,dvpg