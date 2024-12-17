## Author: Paul Brazier
## Version: 0.1
## Purpose: Upload OVF Virtual Machine templates to vCloud
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE

# Last Change by: Paul Brazier
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Initial build
# Adjustments Required: 


## -- Script Variables; check and/or change for every deployment -- ##
$vCloudAddress = "cloud.pulsant.com"
$DeployToSite = "RDG3-PEC4" #Options: RDG3-PEC4, MKN1-PEC4, EDI3-PEC4
$OvfSource = "E:\VM Templates\Windows\201802-Win2016-STD-NSP\201802-Win2016-STD-NSP.ovf"
$OvfName = "201802-Win2016-STD-NSP"

## -- Script Variables; change only if required -- ##
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"

## -- Variable manipulation -- ##
switch ($DeployToSite) {
  MKN1-PEC4 { $Orgvdc = "PEC2 mkn1clouc2 VDC" ; $Catalog = "Public Templates (mkn1clouc2)"}
  RDG3-PEC4 { $Orgvdc = "PEC2 rdg3clouc2 VDC" ; $Catalog = "Public Templates (rdg3clouc2)"}
  EDI3-PEC4 { $Orgvdc = "PEC2 edi3clouc2 VDC" ; $Catalog = "Public Templates (edi3cloum2)"}
  }

## -- Functions -- ##


## -- Open connections -- ##
try {$vCloudConnection = Connect-CIServer -Server $vCloudAddress -Credential $vCloudCredential}
catch {throw}

## -- Verfication section -- ##
Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host

# Initialize error counter
$Script:ErrorCount = 0

# Verify that a file is reachable and exists
if (!(Test-Path $OvfSource -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access $OvfSource }

# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding..." ; Write-Host }

## -- Script actions start here -- ##
Import-CIVAppTemplate -SourcePath $OvfSource -Name $OvfName -OrgVdc $Orgvdc -Catalog $Catalog

## -- Close Connections -- ##
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-CIServer -Server $vCloudAddress -Confirm:$false
Remove-Variable vCloudCredential
Remove-Variable vCloudConnection