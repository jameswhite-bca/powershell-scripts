## Author: Richard Hilton
## Version: 1.0
## Purpose: Change UUID of a single VM
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI

# Last Change by: Richard Hilton
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Initial Release
# Adjustments Required: None


## -- Script Variables; check and/or change for every deployment -- ##
$vCenterName = "vCenterNameGoesHere"
$ResourcePoolName = "ResourcePoolNameGoesHere"
$VMName = "VMNameGoesHere"


## -- Open connections -- ##
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Connect-VIServer -Server $vCenterName -Force


## -- Script actions start here -- ##
$NewVMObjectVI = Get-ResourcePool -Name $ResourcePoolName | Get-VM -Name $VMName
$NewUuid = "{0:x8}" -f (Get-Random 4294967295) + "{0:x8}" -f (Get-Random 4294967295) + "{0:x8}" -f (Get-Random 4294967295) + "{0:x8}" -f (Get-Random 4294967295)
$VMConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$VMConfigSpec.Uuid = $NewUuid
$NewVMObjectVI.Extensiondata.ReconfigVM($VMConfigSpec)


## -- Close Connections -- ##
Disconnect-VIServer -Server $vCenterName
