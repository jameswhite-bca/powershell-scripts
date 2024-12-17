#Author: Richard Hilton
#Version: 0.33
#Purpose: Create NAT rules & run checks on IPs.
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, Posh-SSH module

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Minor Adjustments
#Adjustments Required: Check for Posh-SSH module, review & fix comments and text notifications


# -- Script Variables; change for every deployment --

$NewVMsDataInput = "Script" # Options: "Script" or "CsvFile"
$NewVMsDataInputFilePath = "$env:USERPROFILE\Documents\setme.csv"

$SaveToFile = $false  # $true or $false
$OutputFilePath = "$env:USERPROFILE\Documents\setme.txt"

$ShowFirewallChecks = $true  # $true or $false
$ApplyConfigurationToFirewall = $false  # $true or $false
$FirewallIP = "set me"
$SaveFirewallChanges = $false  # $true or $false


#Set variables; VMs to deploy
<# Example:
Name,IPAddress,PublicIPAddress,FirewallNameIf
SRVR-00000001 (Server 1),<ipaddress>,<publicipaddress>,<firewallnameif>
SRVR-00000003 (Server 2),<ipaddress>,<publicipaddress>,<firewallnameif>
#>

$NewVMsScriptInput = @'
Name,IPAddress,PublicIPAddress,FirewallNameIf

'@ | ConvertFrom-Csv

# -- Script Variables; change only if required --


## -- Functions -- ##
Function Read-FullResponse {
    param ($ShellStream,[int][ValidateRange(50,1000)]$ResponseDelayInMS = 50,[int][ValidateRange(5,300)]$TimeoutInSeconds = 5)
    # Version 0.2
    Remove-Variable Response -ErrorAction SilentlyContinue
    $FullResponse = ""
    $ResponseFinished  = $false
    $TimeoutInCycles = ($TimeoutInSeconds * 1000) / $ResponseDelayInMS
    $SlowAfterCycles = 20
    $SlowResponseDelayInMS = 1000
    $Counter = 0
    do {
        if ($Counter -gt $SlowAfterCycles) {
            $ResponseDelayInMS = $SlowResponseDelayInMS
            $Counter += $SlowAfterCycles
        }
        else {$Counter ++}
        Start-Sleep -Milliseconds $ResponseDelayInMS
        $Response = $ShellStream.Read()
        #Write-Host -ForegroundColor Yellow More: ($Response -match "<--- More --->")
        #Write-Host -ForegroundColor Yellow FRWL: ($Response -match "(FRWL).*\#" -or "(FRWL).*\>" )
        if ($Response -match "<--- More --->") {
            $ShellStream.Write(" ")
            $Response = $Response -replace "`n<--- More --->"
            $Counter = 0
        }
        elseif ($Response -match "(FRWL).*\#" -or $Response -match "(FRWL).*\>") {
            $ResponseFinished = $true
        }
        #elseif ($Counter -gt ($TimeoutInCycles -1)) {throw "Timeout reached"}
        elseif ($Counter -gt ($TimeoutInCycles -1)) {return $FullResponse + "`n" + $Response + "`nTimeout reached"}
        #Write-Host $Response
        $FullResponse += $Response
        #Write-Host ResponseFinished $ResponseFinished
    }
    until ($ResponseFinished -eq $true)
    return $FullResponse
}
#Measure-Command -Expression {Read-FullResponse -ShellStream $ShellStream}

Function Invoke-CiscoCommand {
    param ([string]$Command = "",$ShellStream)
    if ($Dbg) { Write-Host -ForegroundColor Gray Executing $Command }
    if ($Dbg) { Write-Host -ForegroundColor Gray Writting new lines }
    $ShellStream.Write("`n")
    if ($Dbg) { Write-Host -ForegroundColor Gray Written new lines }
    if ($Dbg) { Write-Host -ForegroundColor Gray Reading new line response }
    $Prompt = Read-FullResponse -ShellStream $ShellStream
    if ($Dbg) { Write-Host -ForegroundColor Gray Finished reading new line response }
    if ($Dbg) { Write-Host -ForegroundColor Gray Sending command }
    $ShellStream.Write( $Command + "`n")
    if ($Dbg) { Write-Host -ForegroundColor Gray Finished sending command }
    $Response = Read-FullResponse -ShellStream $ShellStream
    if ($Dbg) { Write-Host -ForegroundColor Gray Finished reading command response }
    $FullResponse = "$Prompt" + "$Response"
    if ($Response -match "ERROR:") {Write-Host -ForegroundColor Red $FullResponse; pause}
    elseif ($Response -match "WARNING:") {Write-Host -ForegroundColor Yellow $FullResponse; pause}
    else { Write-Host -ForegroundColor Green $FullResponse }
    if ($Dbg) { Write-Host -ForegroundColor Gray Finished executing $Command }
    return $FullResponse
}


## -- Open Connections -- ##
if ($ApplyConfigurationToFirewall -eq $true -or $ShowFirewallChecks -eq $true) {
    $FirewallUsername = Read-Host "Enter firewall username"
    $FirewallSecurePassword = Read-Host "Enter firewall password" -AsSecureString
    $FirewallCredentials = New-Object System.Management.Automation.PSCredential ($FirewallUsername, $FirewallSecurePassword)
    $SSHSession = New-SSHSession -ComputerName $FirewallIP -Credential $FirewallCredentials -Force
    if ($SSHSession) {Write-Host -ForegroundColor Green Logged in}
    else {throw}
    #$ShellStream = $SSHSession.Session.CreateShellStream("xterm", 1000, 1000, 1000, 1000, 1000)
    $ShellStream = $SSHSession.Session.CreateShellStream("dumb", 1000, 1000, 1000, 1000, 1000)
    Start-Sleep -Seconds 2
    $Response = Read-FullResponse -ShellStream $ShellStream
    $FirewallUnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($FirewallSecurePassword))
    $ExpectResponse = Invoke-SSHStreamExpectAction -ShellStream $ShellStream -Command "en" -ExpectString "Password:" -Action ($FirewallUnsecurePassword) -TimeOut 15
    Remove-Variable FirewallUsername; Remove-Variable FirewallUnsecurePassword; Remove-Variable FirewallSecurePassword; Remove-Variable FirewallCredentials
    $ShellStream.Write("`n")
    $Response = Read-FullResponse -ShellStream $ShellStream
    if ($Response -notmatch ">" -and $Response -notmatch "#") {Remove-SSHSession -SSHSession $SSHSession; throw "Enable failed"}
    else {Write-Host -ForegroundColor Green Enabled}
}


# -- Verfication section --

Write-Host -ForegroundColor Green "Starting validation checks...`n"

# Initialize error counter
$Script:ErrorCount = 0

# Collect Variables from file if needed, prompt user to select VMs to deploy
switch ($NewVMsDataInput) {
    Script {
        $NatRules = $NewVMsScriptInput | Out-GridView -Passthru -Title "Select VMs to deploy:"
    }
    CsvFile {
        try {$null = Test-Path $NewVMsDataInputFilePath}
        catch {throw}
        $NewVMsFileInput = Get-Content -Raw -Path $NewVMsDataInputFilePath | ConvertFrom-CSV
        $NatRules = $NewVMsFileInput | Out-GridView -Passthru -Title "Select VMs to deploy:"
    }
}

# Check user has selected NAT rules
if (!($NatRules)) {Write-Host -ForegroundColor Red "No NAT rules have been selected, terminating."; Remove-SSHSession -SSHSession $SSHSession; throw}


# Show IP Checks
if ($ShowFirewallChecks -eq $true) {
    foreach ($NatRule in $NatRules) {
        $Commands = ""
        $Commands += "show run | include " + $NatRule.IPAddress + "`n"
        $Commands += "ping " + $NatRule.IPAddress + "`n"
        $Commands += "show arp | include " + $NatRule.IPAddress + "`n"
        $Commands += "show xlate | include " + $NatRule.IPAddress + "`n"
        $Commands += "show route " + $NatRule.IPAddress + "`n"
        $Commands += "`n"
        $Commands += "show run | include " + $NatRule.PublicIPAddress + "`n"
        $Commands += "ping " + $NatRule.PublicIPAddress + "`n"
        $Commands += "show arp | include " + $NatRule.PublicIPAddress + "`n"
        $Commands += "show xlate | include " + $NatRule.PublicIPAddress + "`n"
        $Commands += "show route " + $NatRule.PublicIPAddress + "`n"
        $Commands += "`n"

        $FullResponse = ""
        foreach ($Command in ($Commands -split "`n")) {
            $Response = Invoke-CiscoCommand -Command $Command -ShellStream $ShellStream
            $FullResponse += $Response
        }
        if ($UserResponse) { Remove-Variable UserResponse }
        $SlimResponse = $FullResponse -replace "`r","" -replace "`n"," `n"# -replace "`n`n","`n"
        #$SlimResponse = $FullResponse -replace "`r`n`r`n","`r`n"
        $UserResponse = $SlimResponse -split "`n" | Out-GridView -Title ("Checks for " + $NatRule.Name) -PassThru
        if ($UserResponse) { Write-Host -ForegroundColor Green "Checks for " $NatRule.Name " accepted by user, proceeding...`n" }
        else { Write-Host -ForegroundColor Red "Checks for " $NatRule.Name " rejected by user, aborting...`n" ; Remove-SSHSession -SSHSession $SSHSession ; throw }
    }
}


# Verification evaluation
if ($Script:ErrorCount -ne 0) { Write-Host -ForegroundColor Red $Script:ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }
else { Write-Host -ForegroundColor Green "Validation checks passed successfully, proceeding to deploy VMs.`n" }

# -- Script actions start here --

# Build Configuration
$NewConfiguration = ""

foreach ($NatRule in $NatRules) {
#    $OutsideIPHyphens = $NatRule.PublicIPAddress -replace ".","-"
#    $InsideIPHyphens = $NatRule.IPAddress -replace ".","-"
    $AddressObjectOutsideName = ($NatRule.PublicIPAddress -replace "\.","-") + "_outside"
    $AddressObjectInsideName = ($NatRule.IPAddress -replace "\.","-") + "_inside"
    $NewConfiguration += "object network " + $AddressObjectOutsideName + "`n"
    $NewConfiguration += "  host " + $NatRule.PublicIPAddress + "`n"
    $NewConfiguration += "  description " + $NatRule.Name + "_outside`n"
    $NewConfiguration += "object network " + $AddressObjectInsideName + "`n"
    $NewConfiguration += "  host " + $NatRule.IPAddress + "`n"
    $NewConfiguration += "  description " + $NatRule.Name + "_inside`n"
    $NewConfiguration += "  nat (" + $NatRule.FirewallNameIf + ",outside) static " + $AddressObjectOutsideName + "`n"
    $NewConfiguration += "`n"
}

# Display configuration
#$UserResponse = [System.Windows.MessageBox]::Show($NewConfiguration,'Is configuration correct?','YesNoCancel','Question')
if ($UserResponse) { Remove-Variable UserResponse }
$UserResponse = $NewConfiguration -split "`n" | Out-GridView -Title 'Is configuration correct?' -PassThru
if ($UserResponse) { Write-Host -ForegroundColor Green "Generated configuration accepted by user, proceeding...`n" }
else { Write-Host -ForegroundColor Red "Generated configuration rejected by user, aborting...`n" ; Remove-SSHSession -SSHSession $SSHSession ; throw }

# Write configuration to file if set to do so
if ($SaveToFile -eq $true) {
    Out-File -InputObject $NewConfiguration -FilePath $OutputFilePath
}

# Deploy configuration to firewall if set to do so
if ($ApplyConfigurationToFirewall -eq $true) {
        
    # CheckEnsure no waiting output and that all previous commands are finished.
    $Response = Invoke-CiscoCommand -ShellStream $ShellStream
    if ($Response -notmatch "#") { Remove-SSHSession -SSHSession $SSHSession; throw "Enable check failed" }

    # Enter configuration mode and check successful
    $Response = Invoke-CiscoCommand -Command "conf t" -ShellStream $ShellStream
    if ($Response -notmatch "(config).\#") { Remove-SSHSession -SSHSession $SSHSession; throw "Failed to enter configuration mode" }

        # Send configuration
    foreach ($Command in ($NewConfiguration -split "`n")) {
        $Response = Invoke-CiscoCommand -Command $Command -ShellStream $ShellStream
    }

    # Exit configuration mode
    $Response = Invoke-CiscoCommand -Command "end" -ShellStream $ShellStream

    # Save firewall configuration if set to do so
    if ($SaveFirewallChanges -eq $true) {
        $WriteMemDecision = Read-Host 'Execute "write mem" ? (Y/N)'
        if ($WriteMemDecision -match "Y") { $Response = Invoke-CiscoCommand -Command "write mem" -ShellStream $ShellStream }
    }
}


# -- Close Connections --
if ($ApplyConfigurationToFirewall -eq $true -or $ShowFirewallChecks -eq $true) { Remove-SSHSession -SSHSession $SSHSession }