#Author: Richard Hilton
#Version: 0.42
#Purpose: Disable guest customization on VMs, upgrade virtual hardware version.
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Added to version control, added some additional comments, tidy up.
#Adjustments Required:


# -- Script Variables; change for every deployment --

#Set variables; Deployment target
$vCloudAddress = "cloud.pulsant.com"
$CustomerAccountCode = "set me" # Example: "TEST"
$ShutdownVMs = $false # Options: $true or $false
$NewVMsDataInput = "Script" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = "$env:USERPROFILE\Documents\setme.csv"

#Set variables; VMs to deploy
<# Example:
Name,OrgVDC,vApp
SRVR-00000001 (Server 1),<orgvdcname>,<vappname>
SRVR-00000003 (Server 2),<orgvdcname>,<vappname>
#>

# Alternatively, you can paste in the CSV table you used in the Deploy VMs - vCloud script.
# It will handle the extra properties fine, it just won't use them for anything.

$NewVMsScriptInput = @'
Name,OrgVDC,vApp

'@ | ConvertFrom-Csv


# -- Script Variables; change only if required --

#Set variables; Passwords
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"

# -- Open connections --

#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true

#Connect to vCloud
try {$vCloudConnection = Connect-CIServer -Server $vCloudAddress -Credential $vCloudCredential}
catch {throw}


# -- Verfication section --

Write-Host ; Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host

# Initialize error counter
$Script:ErrorCount = 0

# Collect Variables from file if needed, prompt user to select VMs to deploy
switch ($NewVMsDataInput) {
    Script {
        $NewVMs = $NewVMsScriptInput | Out-GridView -Passthru -Title "Select VMs to disable guest customization on:"
    }
    CsvFile {
        try {$null = Test-Path $NewVMsDataInputFilePath}
        catch {throw}
        $NewVMsFileInput = Get-Content -Raw -Path $NewVMsDataInputFilePath | ConvertFrom-CSV
        $NewVMs = $NewVMsFileInput | Out-GridView -Passthru -Title "Select VMs to disable guest customization on:"
    }
}

# Check user has selected VMs
if (!($NewVMs)) {Write-Host -ForegroundColor Red "No VMs have been selected, terminating."; throw}

# Check Org exists
try {$VerificationOrgObject = Get-Org -Name $CustomerAccountCode}
catch {throw}

# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding to disable guest customization for VMs." ; Write-Host }


# -- Script actions start here --

# Shut down, disable Guest Customization and upgrade hardware version to latest available, Start up VMs if set to do so
if ($ShutdownVMs -eq $true) {
    Foreach ($NewVM in $NewVMs) {

        Write-Host -ForegroundColor Green Disabling guest customization for $NewVM.Name

        # Get VM details
        $NewVMOrg = Get-Org -Name $CustomerAccountCode
        $NewVMOrgVDCObject = Get-OrgVdc -Org $NewVMOrg -Name $NewVM.OrgVDC
        $NewVMvAppObject = $NewVMOrgVDCObject | Get-CIVApp -Name $NewVM.vApp
        $NewVMObject = Get-CIVM -Org $NewVMOrg -OrgVdc $NewVMOrgVDCObject -VApp $NewVMvAppObject -Name $NewVM.Name

        # Shut Down VM
        Write-Host -ForegroundColor DarkGreen Shutting down VM...
        $null = Stop-CIVMGuest -VM $NewVMObject -Confirm:$false
        # Start-Sleep 5

        # Check VM is turned off and Disable Guest Customization and Upgrade hardware version to latest available
        $NewVMObject = Get-CIVM -Org $NewVMOrg -OrgVdc $NewVMOrgVDCObject -VApp $NewVMvAppObject -Name $NewVM.Name
        if ($NewVMObject.Status -eq "PoweredOff" ) {

            # Clear Guest Customization settings
            $NewVMObject.ExtensionData.Section[3].CustomizationScript = $null
            $NewVMObject.ExtensionData.Section[3].AdminPassword = $null
            $NewVMObject.ExtensionData.Section[3].AdminAutoLogonEnabled = $false
            $NewVMObject.ExtensionData.Section[3].AdminAutoLogonCount = $null
            $NewVMObject.ExtensionData.Section[3].AdminPassword = $false
            $NewVMObject.ExtensionData.Section[3].ChangeSid = $false

            # Disable Guest Customization
            $NewVMObject.ExtensionData.Section[3].Enabled = $false

            # Write Section 3 changes to vCloud
            $NewVMObject.ExtensionData.Section[3].UpdateServerData()

            # Upgrade hardware version to latest available
            $NewVMObject.ExtensionData.UpgradeHardwareVersion()


        } else {

            Write-Host -ForegroundColor Red $NewVM.Name did not shut down, aborting...
            return
        }

        # Start VMs
        Write-Host -ForegroundColor DarkGreen Starting up VM...
        $null = Start-CIVM -VM $NewVMObject

        Write-Host -ForegroundColor Green Guest customization disabled for $NewVM.Name ; Write-Host
    }
}

# -- Close Connections --
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-CIServer -Server $vCloudAddress -Confirm:$false
Remove-Variable vCloudCredential
Remove-Variable vCloudConnection