## Author: Richard Hilton
## Version: 0.30
## Purpose: Automate Asigra backup set creation
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE

# Last Change by: Richard Hilton
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Add support for Linux backup sets
# Adjustments Required: 


## -- Script Variables; check and/or change for every deployment -- ##

$DataInputMethod = "Script" # Options: "Script" or "CsvFile"
$DataInputFilePath = "set me"
$AddBackupUsers = $true
$AddHostFile = $true
$DSClientIP = "set me"
$DSClientType = "Linux" # Options: "Windows" or "Linux"
if ($AddHostFile -eq $true) { $DSClientCredential = Get-Credential -Message "Enter DS-Client Administrator username and password" -UserName "Administrator"}
$AutoHotKeyScriptPath = "set me"

#Set variables; DataInput
<# Example:
Name,Hostname,IPAddress,PublicIPAddress,Username,Password,BackupUsername,BackupPassword,BackupSelections
SRVR-00000010,Server1,172.22.10.10,192.0.2.10,Administrator,password1,pulsant-backup,password2,c$;system state;services database
SRVR-00000020,Server2,172.22.11.10,192.0.2.11,Administrator,password3,pulsant-backup,password4,c$;e$;f$;system state;services database
#>

$DataInputScript = @'
Name,Hostname,IPAddress,PublicIPAddress,Username,Password,BackupUsername,BackupPassword,BackupSelections

'@ | ConvertFrom-Csv

## -- Script Variables; change only if required -- ##

# PSExec
$PSExecURL = "http://live.sysinternals.com/psexec.exe"
$PSExecTempFile = $env:TEMP + "\psexec.exe"

# Set Variables; Start-Process Function and Log locations
$stdErrLog = $env:TEMP + "\stdErr.txt"
$stdOutLog = $env:TEMP + "\stdOut.txt"

$AutoHotKeyTemplatePrefix = @'
^j::
'@

$AutoHotKeyTemplateSelection = @'
    Sendraw, <BackupSelection>
    Sleep, 200
    Send, {alt down}a{alt up}
    Sleep, 1000

'@

$AutoHotKeyTemplateBackupSet = @'

    ; <ServerName>
    Send, {alt down}sn{alt up}                                     ;New backupset
    Sleep, 2000
    Send, {alt down}n{alt up}
    Sleep, 200
    Send, {Tab}<Hostname>{alt down}n{alt up}    ;Specify computername
    Sleep, 200
    Send, <BackupUsername>{Tab}{Tab}                               ;Specify username
    Sleep, 200
    Sendraw, <BackupPassword>                                      ;Specify password
    Sleep, 200
    Send, {alt down}o{alt up}                                      ;Add credentials
    Sleep, 5000
    Send, {Tab}
    Sleep, 200
<BackupSelections>    Send, {alt down}n
    Sleep, 200
    Send, n
    Sleep, 200
    Send, n
    Sleep, 200
    Send, n
    Sleep, 200
    Send, n 
    Sleep, 200
    Send, a
    Sleep, 200
    Send, l{alt up}
    Sleep, 200
    Send, incomplete
    Sleep, 200
    Send, {alt down}o
    Sleep, 200
    Send, n
    Sleep, 200
    Send, u
    Sleep, 200
    Send, n
    Sleep, 200
    Send, s
    Sleep, 200
    Send, n
    Sleep, 200
    Send, t
    Sleep, 200
    Send, n{alt up}
    Sleep, 5000

'@

$AutoHotKeyTemplateSuffix = @'

Return
'@

$UserAddTemplate = @'
Net user "<BackupUsername>" <BackupPassword> /add && WMIC USERACCOUNT WHERE "Name='<BackupUsername>'" SET PasswordExpires=FALSE && Net localgroup Administrators "<BackupUsername>" /add && 
'@

$OtherCommands = @'
Reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system /t REG_DWORD /v "LocalAccountTokenFilterPolicy" /d 00000001 /f
'@

## -- Variable manipulation -- ##


## -- Functions -- ##

Function Show-ProcessResult {
    Get-Content -Path $stdOutLog | Select-Object -Last 1 | Write-Host -ForegroundColor Green
    Write-Output ""
    Get-Content -Path $stdErrLog | Select-Object -Last 1 | Write-Host -ForegroundColor Yellow
}

## -- Open connections -- ##


## -- Verfication section -- ##

Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host

# Initialize error counter
$Script:ErrorCount = 0

# Collect Variables from file if needed, prompt user to select VMs to deploy
switch ($DataInputMethod) {
    Script {
        $Data = $DataInputScript | Out-GridView -Passthru -Title "Select items:"
    }
    CsvFile {
        try {$null = Test-Path $DataInputFilePath}
        catch {throw}
        $DataInputFile = Get-Content -Raw -Path $DataInputFilePath | ConvertFrom-CSV
        $Data = $DataInputFile | Out-GridView -Passthru -Title "Select items:"
    }
}

# Check user has selected items
if (!($Data)) {Write-Host -ForegroundColor Red "No items have been selected, terminating." ; Pause ; throw}


# Example verification that a file is reachable and exists
# if (!(Test-Path $ExamplePath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access example path $ExamplePath }

# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding..." ; Write-Host }


## -- Script actions start here -- ##

# Download required files
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile($PSExecURL,$PSExecTempFile)

# Check files have downloaded
if (!(Test-Path $PSExecTempFile)) {Write-Host -Fo Red PSExec Missing, terminating; throw}

# Add servers to DS-Client hosts file
if ($AddHostFile -eq $true) {
    New-PSDrive -PSProvider FileSystem -Name "DSClient" -Root "\\$DSClientIP\C$" -Credential $DSClientCredential

    Foreach ($Server in $Data) {
        $CurrentHostsFile = Get-Content "DSClient:\Windows\System32\drivers\etc\hosts" -raw
        if ($CurrentHostsFile -match $Server.Hostname) {Write-Host $Server.Name $Server.Hostname ":" Already Exists} else {
            if ($CurrentHostsFile[-1] -ne "`n") { Add-Content -Path "DSClient:\Windows\System32\drivers\etc\hosts" -Value "" -Encoding ascii }
            $HostFileAddition = $Server.IPAddress + " " + $Server.Hostname
            $HostFileAddition | Add-Content -Path "DSClient:\Windows\System32\drivers\etc\hosts" -Encoding ascii
        }
    }
    Remove-PSDrive "DSClient"
}

# Create backup users, run other commands

Foreach ($Server in $Data) {
    $ServerCommands = ""
    if ($AddBackupUsers -eq $true) { $ServerCommands += $UserAddTemplate -replace "<BackupUsername>", $Server.BackupUsername -replace "<BackupPassword>", $Server.BackupPassword }
    $ServerCommands += $OtherCommands

    # Build explicit variables
    $ServerIPAddress = $Server.PublicIPAddress
    $ServerUsername = $Server.Username
    $ServerPassword = $Server.Password

    # Build PSExec Argument string
    $PSExecArguments = @"
\\$ServerIPAddress -u $ServerUsername -p $ServerPassword "cmd" /c $ServerCommands
"@

    # Run PSExec
    $null = Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $PSExecTempFile -ArgumentList $PSExecArguments

    # Show result of PSExec
    $null = Show-ProcessResult
    #Write-Host -ForegroundColor Green Salt installation finished for $NewVM.Name ; Write-Host

}

# Generate AutoHotKey script

$AutoHotKeyScript = ""
$AutoHotKeyScript += $AutoHotKeyTemplatePrefix

Foreach ($Server in $Data) {
    $AutoHotKeyScriptServer = $AutoHotKeyTemplateBackupSet
    $AutoHotKeyScriptServer = $AutoHotKeyScriptServer -replace "<ServerName>", $Server.Name -replace "<Hostname>", $Server.Hostname -replace "<BackupUsername>", $Server.BackupUsername -replace "<BackupPassword>", $Server.BackupPassword
    $ServerBackupSelections = $Server.BackupSelections -split ";"
    $AutoHotKeyScriptServerSelections = ""
    Foreach ($ServerBackupSelection in $ServerBackupSelections) { $AutoHotKeyScriptServerSelections += $AutoHotKeyTemplateSelection -replace "<BackupSelection>", $ServerBackupSelection }
    $AutoHotKeyScript += $AutoHotKeyScriptServer -replace "<BackupSelections>", $AutoHotKeyScriptServerSelections
}

$AutoHotKeyScript += $AutoHotKeyTemplateSuffix

$AutoHotKeyScript = $AutoHotKeyScript -replace '%','`%'
$AutoHotKeyScript | Out-File -FilePath $AutoHotKeyScriptPath

## -- Close Connections -- ##


