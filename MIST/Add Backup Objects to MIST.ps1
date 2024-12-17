## Author: Richard Hilton
## Version: 0.2
## Purpose: Add Backup objects to MIST.
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE, Disable any broswer addons the add features to text boxes e.g. grammerly

# Last Change by: Paul Brazier
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Added Backup column to script input, removed unexpected { in script, discovered broswer addons can affect tabbing.
# Adjustments Required: 

$NewVMsDataInput = "Script" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = "set me"
$AutoHotkeyScriptPath = "set me"
$WaitPeriodLongMS = 2000
$WaitPeriodShortMS = 200

#Set variables; DataInput
<# Example:
Name,Hostname,Backup,BackupDestinationSite,MistOID
MY VM1,VM1,Asigra,edi3,12345
#>

$NewVMsScriptInput = @'
Name,Hostname,Backup,BackupDestinationSite,MistOID

'@ | ConvertFrom-Csv


# Collect Variables from file if needed, prompt user to select VMs to deploy
switch ($NewVMsDataInput) {
    Script {
        $NewVMs = $NewVMsScriptInput | Out-GridView -Passthru -Title "Select VMs to deploy:"
    }
    CsvFile {
        try {$null = Test-Path $NewVMsDataInputFilePath}
        catch {throw}
        $NewVMsFileInput = Get-Content -Raw -Path $NewVMsDataInputFilePath | ConvertFrom-CSV
        $NewVMs = $NewVMsFileInput | Out-GridView -Passthru -Title "Select VMs to deploy:"
    }
}

# Check user has selected VMs
if (!($NewVMs)) {Write-Host -ForegroundColor Red "No VMs have been selected, terminating."; throw}

$AutoHotkeyScript = @'
^k::

'@

foreach ($NewVM in $NewVMs) {
    $ObjectID = $NewVM.MistOID
    $BackupURL = "https://mist.pulsant.com/objects/edit.php?type=backup&child=" + $ObjectID
    $BackupDestinationSite = $NewVM.BackupDestinationSite
    $Hostname = $NewVM.Hostname
    if ($NewVM.Backup -like "Asigra") {
        $AutoHotkeyScript +=
            "`n" ,
            "    Send, {F6}" , "`n" ,
            "    Sleep $WaitPeriodShortMS" , "`n" ,
            "    Send, $BackupURL{Enter}" , "`n" ,
            "    Sleep $WaitPeriodLongMS"  , "`n" ,
            "    Send, {Shift Down}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Shift Up}" , "`n" ,
            "    Send, {Tab}{Tab}{Tab}cloud backup{Tab}Cloud - $BackupDestinationSite.backup.pulsant.com{Tab}{Tab}cloud backup - protected server{Tab}{Tab}{Tab}$Hostname{Enter}"  , "`n"
            }
}

$AutoHotkeyScript += "Return"
$AutoHotkeyScript | Out-File -FilePath $AutoHotkeyScriptPath