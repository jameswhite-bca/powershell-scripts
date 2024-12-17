#Author: Paul Brazier
#Version: 0.2
#Purpose: HP Host worksheet checks - Will check cluster wide pre-reqs for HP 3PAR upgrades
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by: n/a
#Status: Not ready for use!
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes:
#Adjustments Required: Format outputs and include other check commands

# -- Script Variables; change for every deployment --
$vCenterAddress = 'localhost'
#$cluster = 'build room'
$VMHosts = Get-Datacenter | Get-VMHost
# HBA examples = FibreChannel, IScsi
$HBA = 'IScsi'

# -- Script Variables; change only if required --
#Set variables; Passwords
#$vCenterCredential = Get-Credential -Message 'Enter your vCenter Credentials'

# Pipe the Get-esxcli cmdlet into the $esxcli variable
#$esxcli = $vmhost | get-esxcli

# -- Open connections --
#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $false
#Connect to vCenter
$null = Connect-VIServer -Server $vCenterAddress -ErrorAction Stop

foreach ($HostDetail in $VMHosts){
 Get-VMHost | fl -Property NetworkInfo, Parent, Version, Build
 Get-VMHostHba -VMHost $HostDetail.Name -Type $HBA | fl -Property VMHost, Driver, Model
}

# -- Testing commands --

# Get-VMHost | fl -Property NetworkInfo, Parent, Version, Build

# get-view -ViewType HostSystem -Property Name, Config.Product | select Name,{$_.Config.Product.FullName},{$_.Config.Product.Build} | ft -auto

# Get-VMHostHba -VMHost $HostDetail.Name | fl -Property VMHost, Model, Driver

# Get-VMHostModule -VMHost $HostDetail.Name iscsi_vmk | fl

# Get-VMHostModule -VMHost $HostDetail.Name | fl
