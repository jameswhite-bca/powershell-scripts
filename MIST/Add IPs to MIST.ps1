## Author: Richard Hilton
## Version: 0.32
## Purpose: Add CIDRs to MIST.
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE

# Last Change by: Richard Hilton
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Initial build
# Adjustments Required: 

$NewVMsDataInput = "Script" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = "set me"
$AutoHotkeyScriptPath = "set me"
$WaitPeriodMS = 2000

#Set variables; DataInput
<# Example:
Name,IPAddress,PublicIPAddress,CIDRDescription
SRVR-00000001,192.168.0.10,
#>

$NewVMsScriptInput = @'
Name,IPAddress,PublicIPAddress,Network,CIDRDescription,MistOID

'@ | ConvertFrom-Csv

# Example

#Set variables; DataInput
<# Example:
Name,MistOID
Inside,111111
Gateway,111112
Web,111113
#>

$Networks = @'

'@ | ConvertFrom-Csv

# Functions; Check if address family
function Check-AddressFamily {
    param ([Net.IPAddress]$IP)
    # Check 10.0.0.0/8
    if ( ($IP.Address -band ([Net.IPAddress]"255.0.0.0").Address) -eq (([Net.IPAddress]"10.0.0.0").Address) ) { return "Private" }
    # Check 172.16.0.0/12 "255.240.0.0"
    elseif ( ($IP.Address -band ([Net.IPAddress]"255.240.0.0").Address) -eq (([Net.IPAddress]"172.16.0.0").Address) ) { return "Private" }
    # Check 192.168.0.0/16
    elseif ( ($IP.Address -band ([Net.IPAddress]"255.255.0.0").Address) -eq (([Net.IPAddress]"192.168.0.0").Address) ) { return "Private" }
    else {return "Public"}
}

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
    $NetworkID = $null
    foreach ($Network in $Networks) { if ($Network.Name -like $NewVM.Network) { $NetworkID = $Network.MistOID } }
    $ExtIP = $NewVM.PublicIPAddress
    $IntIP = $NewVM.IPAddress
    $CIDRDescription = $NewVM.CIDRDescription
    $CIDRURL = "https://mist.pulsant.com/objects/edit.php?type=cidr&child=" + $ObjectID
    
    if ($ExtIP) {
        $AutoHotkeyScript +=
            "`n" ,
            "    Send, {F6}" , "`n" ,
            "    Sleep $WaitPeriodMS" , "`n" ,
            "    Send, $CIDRURL{Enter}" , "`n" ,
            "    Sleep $WaitPeriodMS"  , "`n" ,
            "    Send, {Shift Down}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Shift Up}" , "`n"

        switch (Check-AddressFamily -IP $ExtIP) {
            Private {
                if ($CIDRDescription)  { $AutoHotkeyScript += "    Sendraw, $CIDRDescription" , "`n" , "    Send, {Space}" , "`n" }
                $AutoHotkeyScript += 
                    "    Send, Public{Tab}{Tab}{Tab}$ExtIP/32{Tab}{Shift Down}{Tab}{Tab}{Shift Up}$NetworkID" , "`n" ,
                    "    Sleep $WaitPeriodMS" , "`n" ,
                    "    Send, {Tab}{Tab}{Tab}n{Tab}{Tab}{Enter}" , "`n" ,
                    "    Sleep $WaitPeriodMS" , "`n"
            }
            Public {
                if ($CIDRDescription)  { $AutoHotkeyScript += "    Sendraw, $CIDRDescription" , "`n" , "    Send, {Space}" , "`n" }
                $AutoHotkeyScript +=
                    "    Send, Public{Tab}{Tab}{Tab}$ExtIP/32{Tab}{Tab}n{Tab}{Tab}{Enter}"  , "`n"
            }
        }
    }

    if ($IntIP) {
        $AutoHotkeyScript +=
            "`n" ,
            "    Send, {F6}" , "`n" ,
            "    Sleep $WaitPeriodMS" , "`n" ,
            "    Send, $CIDRURL{Enter}" , "`n" ,
            "    Sleep $WaitPeriodMS"  , "`n" ,
            "    Send, {Shift Down}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Tab}{Shift Up}" , "`n"

        switch (Check-AddressFamily -IP $IntIP) {
            Private {
                if ($CIDRDescription)  { $AutoHotkeyScript += "    Sendraw, $CIDRDescription" , "`n" , "    Send, {Space}" , "`n" }
                $AutoHotkeyScript += 
                    "    Send, Private{Tab}{Tab}{Tab}$IntIP/32{Tab}{Shift Down}{Tab}{Tab}{Shift Up}$NetworkID" , "`n" ,
                    "    Sleep $WaitPeriodMS" , "`n" ,
                    "    Send, {Tab}{Tab}{Tab}n{Tab}{Tab}{Enter}" , "`n" ,
                    "    Sleep $WaitPeriodMS" , "`n"
            }
            Public {
                if ($CIDRDescription)  { $AutoHotkeyScript += "    Sendraw, $CIDRDescription" , "`n" , "    Send, {Space}" , "`n" }
                $AutoHotkeyScript +=
                    "    Send, Private{Tab}{Tab}{Tab}$IntIP/32{Tab}{Tab}n{Tab}{Tab}{Enter}"  , "`n"
            }
        }
    }
}    
    
$AutoHotkeyScript += "Return"
$AutoHotkeyScript | Out-File -FilePath $AutoHotkeyScriptPath