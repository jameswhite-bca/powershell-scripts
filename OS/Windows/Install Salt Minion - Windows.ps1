#Author: Richard Hilton
#Version: 0.42
#Purpose: Install Salt on remote windows servers / VMs
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Additional Comments, adjusted order of Variables
#Adjustments Required: Additional Comments

# -- Variables Section --

# -- Script Variables; change for every deployment --

# Set variables; Data source
$NewVMsDataInput = "Script" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = "$env:USERPROFILE\Documents\setme.csv"

# Set Variables; Specify Servers to install Salt on

<# Example:
$NewVMs = @'
Name,INST,PublicIPAddress,Username,Password
SRVR-00000001,INST-00000002,198.51.100.1,administrator,password1
SRVR-00000003,INST-00000004,198.51.100.2,administrator,password2
'@ | ConvertFrom-Csv
#>

$NewVMsScriptInput = @'
Name,INST,PublicIPAddress,Username,Password

'@ | ConvertFrom-Csv


# -- Script Variables; change only if required --

# Set Variables; General servers & paths
$SaltMasters = "europa.piiplat.com","sinope.piiplat.com","ananke.piiplat.com","kale.piiplat.com"
$PSExecURL = "http://live.sysinternals.com/psexec.exe"
$SaltMinionURL = "http://46.236.30.43/cfmwinshare/salt/Salt-Minion-Current.exe"
$RemoteWorkingDirectory = "C:\Windows\Temp"
$PSExecTempFile = $env:TEMP + "\psexec.exe"
$SaltTempFile = "C:\Windows\Temp\salt-minion.exe"


# Set Variables; Start-Process Function and Log locations
$stdErrLog = $env:TEMP + "\stdErr.txt"
$stdOutLog = $env:TEMP + "\stdOut.txt"
Function Show-ProcessResult {
    Get-Content -Path $stdOutLog | Select-Object -Last 1 | Write-Host -ForegroundColor Green
    echo ""
    Get-Content -Path $stdErrLog | Select-Object -Last 1 | Write-Host -ForegroundColor Yellow
}


# -- Verfication section --

Write-Host ; Write-Host -ForegroundColor Green "Starting validation checks..." ; Write-Host

# Initialize error counter
$Script:ErrorCount = 0

# Collect Variables from file if needed, prompt user to select VMs to deploy
switch ($NewVMsDataInput) {
    Script {
        $NewVMs = $NewVMsScriptInput | Out-GridView -Passthru -Title "Select servers to install salt on:"
    }
    CsvFile {
        try {$null = Test-Path $NewVMsDataInputFilePath}
        catch {throw}
        $NewVMsFileInput = Get-Content -Raw -Path $NewVMsDataInputFilePath | ConvertFrom-CSV
        $NewVMs = $NewVMsFileInput | Out-GridView -Passthru -Title "Select servers to install salt on:"
    }
}

# Check user has selected VMs
if (!($NewVMs)) {Write-Host -ForegroundColor Red "No VMs have been selected, terminating."; throw}

# Check VM details
foreach ($NewVM in $NewVMs) {

    # Check required details are present
    if (!($NewVM.Name)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Server/VM Name not specified ; throw}
    if (!($NewVM.INST)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red INST Code not specified for $NewVM.Name}
    if (!($NewVM.PublicIPAddress)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red PublicIPAddress not specified for $NewVM.Name}
    if (!($NewVM.Username)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Username not specified for $NewVM.Name}
    if (!($NewVM.Password)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Password not specified for $NewVM.Name}

    # Check VMs are contactable
    if (!(Test-Connection -ComputerName $NewVM.PublicIPAddress -Count 2 -Delay 1 -Quiet)) {
        $Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Cannot contact $NewVM.Name at $NewVM.PublicIPAddress
    }
}

# Verification evaluation
if ($ErrorCount -ne 0) { Write-Host -ForegroundColor Red $ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding to install salt." ; Write-Host }


# -- Script actions start here --

# Check if files already exist, erase them if they do
if (Test-Path $PSExecTempFile) {erase $PSExecTempFile}
if (Test-Path $SaltTempFile) {erase $SaltTempFile}

# Download required files
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile($PSExecURL,$PSExecTempFile)
$WebClient.DownloadFile($SaltMinionURL,$SaltTempFile)

# Check files have downloaded
if (!(Test-Path $PSExecTempFile)) {Write-Host -Fo Red PSExec Missing, terminating; throw}
if (!(Test-Path $SaltTempFile)) {Write-Host -Fo Red Salt Installer Missing, terminating; throw}

# Build file name and path variables
$SaltTempFileName = (Get-Item $SaltTempFile).Name
$RemoteWorkingFile = $RemoteWorkingDirectory + "\" + $SaltTempFileName

# Install Salt on listed VMs
Foreach ($NewVM in $NewVMs) {

    Write-Host -ForegroundColor Green Starting salt installation for $NewVM.Name

    # Build explicit variables
    $SaltMaster = Get-Random -InputObject $SaltMasters
    $NewVMPublicIPAddress = $NewVM.PublicIPAddress
    $NewVMUsername = $NewVM.Username
    $NewVMPassword = $NewVM.Password
    $NewVMINST = $NewVM.INST

    # Build PSExec Argument string
    $PSExecArguments = @"
\\$NewVMPublicIPAddress -u $NewVMUsername -p $NewVMPassword -c "$SaltTempFile" -w "$RemoteWorkingDirectory" "$RemoteWorkingFile" /S /master=$SaltMaster /minion-name=$NewVMINST
"@

    # Install Salt
    $null = Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $PSExecTempFile -ArgumentList $PSExecArguments

    # Show result of PSExec
    $null = Show-ProcessResult
    Write-Host -ForegroundColor Green Salt installation finished for $NewVM.Name ; Write-Host

}

# Cleanup
if (Test-Path $PSExecTempFile) {erase $PSExecTempFile}
if (Test-Path $SaltTempFile) {erase $SaltTempFile}