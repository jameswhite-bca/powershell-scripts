## Author: Richard Hilton
## Version: 0.1
## Purpose: Template for script creation with comment sections and some initial code.
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE

# Last Change by: Richard Hilton
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Initial build
# Adjustments Required: 


## -- Script Variables; check and/or change for every deployment -- ##

$DataInputMethod = "Script" # Options: "Script" or "CsvFile"
$DataInputFilePath = "$env:USERPROFILE\Documents\setme.csv"

#Set variables; DataInput
<# Example:
Name,Property1,Property2
Server 1,Field 1,Field 2
Server 2,Field 1,Field 2
#>

$DataInputScript = @'
Name,Property1,Property2

'@ | ConvertFrom-Csv

## -- Script Variables; change only if required -- ##


## -- Variable manipulation -- ##


## -- Functions -- ##


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
        $DataInputFile = Get-Content -Raw -Path $NewVMsDataInputFilePath | ConvertFrom-CSV
        $Data = $DataInputFile | Out-GridView -Passthru -Title "Select items:"
    }
}

# Example verification that a file is reachable and exists
if (!(Test-Path $ExamplePath -ErrorAction SilentlyContinue)) {$Script:ErrorCount ++ ; Write-Host -ForegroundColor Red Could not access example path $ExamplePath }

# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding..." ; Write-Host }


## -- Script actions start here -- ##


## -- Close Connections -- ##
