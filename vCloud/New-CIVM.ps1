## Author: James White
## Version: 0.1
## Purpose: To deploy VM(s) to PEC
## Dependencies: 

# Last Change by: 
# Status: 
# Recommended Run Mode: 
# Changes: 
# Adjustments Required: 

<#
.SYNOPSIS
.DESCRIPTION 
.PARAMETER vapp
The name of the vApp in which you want the VM(s) to be deployed in
.PARAMETER name
The name of the VM object in vCloud Director
.PARAMETER hostname
The hostname of the computer within the guest OS
.PARAMETER os
The operating system of the machine
.PARAMETER pecplatform
The Pulsant Enterprise Cloud Platform to retreive the template from
.EXAMPLE
.\New-CiVM.ps1 -vapp 'PROV mkn1clouc2 VDC1 servers' -name SRVR-JAMESTEST -hostname JW-DC1 -os Win2019 -pecplatform MKN1-PEC4
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [string]$vapp,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [string]$name,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [string]$hostname,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [ValidateSet('Win2012R2','Win2016','Win2019')]
    [string]$os,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [string]$cpu,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [string]$ram,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [ValidateSet('MKN1-PEC4','EDI3-PEC4')]
    [string]$pecplatform
)

switch ( $pecplatform )
    {
        MKN1-PEC4 { $pec2VDC = 'PEC2 mkn1clouc2 VDC'    }
        EDI3-PEC4 { $pec2VDC = 'PEC2 edi3clouc2 VDC'    }
        RDG3-PEC4 { $pec2VDC = 'PEC2 rdg3clouc2 VDC'    }
        MKN1-PEC3 { $pec2VDC = 'PEC2 MKN1-CLOU-V01 VDC' }
        EDI3-PEC3 { $pec2VDC = 'PEC2 EDI3-CLOU-V01 VDC' }  
        RDG3-PEC3 { $pec2VDC = 'PEC2 RDG3-CLOU-V01 VDC' }
}

New-CIVM -VApp $vapp -Name $name -ComputerName $hostname -VMTemplate (Get-CIVMTemplate | Where-Object {$_.Name -clike "*$os*" -and $_.OrgVdc -clike "$pec2VDC"})

$vm = Get-CIVM -Name $name
    
    # Set CPU
    $vm.ExtensionData.Section[0].Item[5].VirtualQuantity.Value = $cpu
    $vm.ExtensionData.Section[0].Item[5].ElementName.Value = $cpu + " virtual CPU(s)"

        # Set RAM
    if ($vm.ExtensionData.Section[0].Item[6].AllocationUnits.Value -eq "byte * 2^20") {
        $vm.ExtensionData.Section[0].Item[6].VirtualQuantity.Value = [UInt64]$RAM * 1024
    }

        # Write Section 0 changes to vCloud
    $vm.ExtensionData.Section[0].UpdateServerData()