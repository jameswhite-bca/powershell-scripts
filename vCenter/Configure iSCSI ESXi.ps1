#Author: Richard Hilton
#Version: 1.1
#Last Change by: Richard Hilton
#Changes: Tidy up, add a few comments

#Status: New, tested, ready to use.
#Recommended Run Mode: Semi-automatic; Powershell ISE; Manual execution of whole script
#Adjustments Required: Ability to create & configure dvportgroups & vmkernels,
				# adjustment to CSV input format to allow ip configuration data input
				# adjustment to configure 3PAR target name as array name



#Build Variables
#FQDNs or IP addresses of ESXi Hosts to Configure
#Enclose each host in quotes and separate with a comma.
#Example: $ESXiHosts = "inst-00000001", "inst-00000002"
#$ESXiHosts = "", "", "", "" # <CHANGE or comment THIS LINE>
#$ESXiHosts = Get-VMHost # Run this instead for all hosts on a vCenter (New clusters only) 
# Alternatively, you could get hosts from a specific cluster


$ESXiHosts = @'
Name,AddiSCSIVMKernels,iSCSI1IP,iSCSI1Mask,iSCSI2IP,iSCSI2Mask,CHAPTarget,CHAPInitiator

'@ | ConvertFrom-Csv

$StorageSystem = "set me"
$iSCSI1DVPortgroup = "set me"
$iSCSI2DVPortgroup = "set me"
$dvSwitchName = "set me"

switch ($StorageSystem) {
    Dedicated3PAR {
        $Targets = "set me", "set me", "set me", "set me"
        $CHAPEnabled = "Yes"
        $CHAPName = "set me"
        $MTU = 1500
    }
    MKN1-3PAR-2 {
        $Targets = "10.11.0.1", "10.11.0.2", "10.11.0.3", "10.11.0.4", "10.12.0.1", "10.12.0.2", "10.12.0.3", "10.12.0.4"
        $CHAPEnabled = "Yes"
        $CHAPName = "MKN1-3PAR-2"
        $MTU = 1500
    }
    RDG3-3PAR-3 {
        $Targets = "10.13.0.1", "10.13.0.2", "10.13.0.3", "10.13.0.4", "10.14.0.1", "10.14.0.2", "10.14.0.3", "10.14.0.4"
        $CHAPEnabled = "Yes"
        $CHAPName = "RDG3-3PAR-3"
        $MTU = 1500
    }
}


# -- Script actions start here --

#Initialize PowerCLI
#. "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False

#Connect to vCenter
Connect-VIServer localhost

#Applies configuration to each host
Foreach ($ESXiHost in $ESXiHosts) {

    # Configure default multipath policy
    $esxcli = Get-EsxCli -VMHost $ESXiHost.Name
    $esxcli.storage.nmp.satp.set($null, "VMW_PSP_RR", "VMW_SATP_ALUA")
    $esxcli.storage.nmp.satp.set($null, "VMW_PSP_RR", "VMW_SATP_DEFAULT_AA")

    # Enable iSCSI Software Adapter
    Get-VMHostStorage -VMHost $ESXiHost.Name | Set-VMHostStorage -SoftwareIScsiEnabled $True

    # Configure iSCSI Software Adapter
    $ESXiHostHBA = Get-VMHostHba -Type iScsi -VMHost $ESXiHost.Name | Where {$_.Model -eq "iSCSI Software Adapter"}

    # Write initator name to variable for final printout
    $script:Initiators += ,@($ESXiHostHBA.IscsiName)

        # Create iSCSI-1 & iSCSI-2 VMKernels
        if ($ESXiHost.AddiSCSIVMKernels -match "Yes") {
            $dvSwitchObject = Get-VDSwitch $dvSwitchName
            $iSCSI1DVPortGroupObject = Get-VDSwitch | Get-VDPortgroup | Where-Object -Property "Name" -Match -Value $iSCSI1DVPortgroup
            $iSCSI2DVPortGroupObject = Get-VDSwitch | Get-VDPortgroup | Where-Object -Property "Name" -Match -Value $iSCSI2DVPortgroup
            New-VMHostNetworkAdapter -VMHost $ESXiHost.Name -VirtualSwitch $dvSwitchObject -PortGroup $iSCSI1DVPortGroupObject -IP $ESXiHost.iSCSI1IP -SubnetMask $ESXiHost.iSCSI1Mask -Mtu $MTU
            New-VMHostNetworkAdapter -VMHost $ESXiHost.Name -VirtualSwitch $dvSwitchObject -PortGroup $iSCSI2DVPortGroupObject -IP $ESXiHost.iSCSI2IP -SubnetMask $ESXiHost.iSCSI2Mask -Mtu $MTU
        }

            # Add new targets
    foreach ($Target in $Targets) {
        # Check to see if the SendTarget exist, if not add it
        if (Get-IScsiHbaTarget -IScsiHba $ESXiHostHBA -Type Send | Where {$_.Address -cmatch $Target}) {
            Write-Host "The target $target does exist on $ESXiHost.Name" -ForegroundColor Red
        }
        else {
            Write-Host "The target $target doesn't exist on $ESXiHost.Name" -ForegroundColor Magenta
            Write-Host "Creating $target on $ESXiHost.Name..." -ForegroundColor Magenta
            if ($CHAPEnabled -match "Yes") {
                New-IScsiHbaTarget -IScsiHba $ESXiHostHBA -Address $Target -ChapType Required -ChapName $ESXiHostHBA.IscsiName -ChapPassword $ESXiHost.CHAPInitiator -MutualChapEnabled $True -MutualChapName $CHAPName -MutualChapPassword $ESXiHost.CHAPTarget
            }
        }
    }
    # Below command deprecated, replaced by adjusting default pathing policy. Below command does not require a reboot, however.
    # Get-VMHost $ESXiHost | Get-ScsiLun -LunType disk | Where-Object {$_.Vendor -eq $Vendor} | Set-ScsiLun -MultipathPolicy "roundrobin" 
}

Foreach ($ESXiHost in $ESXiHosts) {
    Get-VMHost $ESXiHost.Name | Get-VMHostStorage -RescanAllHba
    Write-Host; Write-Host $ESXiHost.Name
    Get-Datastore -RelatedObject (Get-VMHost $ESXiHost.Name) | ft
}

$script:Initiators
Remove-Variable -Name Initiators
