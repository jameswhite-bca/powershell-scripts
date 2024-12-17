## Author: Richard Hilton
## Version: 2.2
## Purpose: Add Service v2 firewall rules to edge gateways.
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE

# Last Change by: Richard Hilton
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Create save config folder if does not exist
# Adjustments Required: 

## -- Script Variables; check and/or change for every deployment -- ##

# During checks, show edge gatewys that have already been configured
$ShowComplete = $false # $true or $false

# After checks, proceed to add the new firewall rules
$ConfigureFirewalls = $false # $true or $false

# During checks, take a backup of the XML config of each selected edge gateway
$SaveConfig = $false # $true or $false
$SaveConfigPath = "Z:\EdgeGatewayBackups\"

## -- Open connections -- ##

if (!$CIServerConnection) { $CIServerConnection = Connect-CIServer cloud.pulsant.com -ErrorAction Stop }
elseif ($CIServerConnection.IsConnected -ne $true) { $CIServerConnection = Connect-CIServer cloud.pulsant.com -ErrorAction Stop } 

## -- Verfication section -- ##

if ($CIServerConnection.IsConnected -ne $true) {throw "vCloud Connection Failed"}

$EdgeGateways = Search-Cloud -QueryType EdgeGateway

$EdgeGateways = $EdgeGateways | Sort-Object -Property Name

$EdgeGateways = $EdgeGateways | Out-GridView -Title "Select Edge Gateways to check" -PassThru

if ( ! (Test-Path $SaveConfigPath) ) {md $SaveConfigPath}

if ($EdgeGateways -eq $null) {
    Write-Host -ForegroundColor Red No Edge Gateways selected. Cancelling.
    throw
}

$TotalComplete = @()
$TotalPartial = @()
$TotalFirewallDisabled = @()
$TotalToConfigure = @()
$TotalSupportRuleNonStandard = @()

foreach ($EdgeGateway in $EdgeGateways) {

    $EdgeGatewayView = $EdgeGateway | Get-CIView

      # Set headers for Get operation
    $GetHeaders = @{
        "x-vcloud-authorization" = [string]$CIServerConnection.SessionSecret
        "Accept" = "application/*+xml;version=20.0"
    }

      # Get edge gateway details via REST
    $EdgeGatewayGetResponse = Invoke-WebRequest -Method Get -Uri $EdgeGatewayView.Href -Headers $GetHeaders
    [xml]$EdgeGatewayGetResponseXML = $EdgeGatewayGetResponse.Content
    
      # Save config to file if set to do so
    if ($SaveConfig -eq $true) {
        [string]$ConfigPath = $SaveConfigPath + "\" + $EdgeGateway.Name + ".xml"
        [string]$EdgeGatewayGetResponse.Content | Out-File -FilePath $ConfigPath
    }

      # Check if firewall is enabled
    if ($EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.IsEnabled -ne $true) {
        Write-Host -ForegroundColor Magenta Skipping $EdgeGatewayGetResponseXML.EdgeGateway.name: Firewall is not enabled.
        $TotalFirewallDisabled += $EdgeGateway
        continue
    }
    
      # Check which Service v2 rules already exist
    $AlreadyDone = 0
    $RDG3Done = 0
    $OnyxDone = 0
    $EDI3Done = 0
    $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule | foreach {
        if ($_.SourceIp -eq "89.151.73.128/27") {
            $AlreadyDone ++
            $RDG3Done ++
        }
    }
    $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule | foreach {
        if ($_.SourceIp -eq "195.97.223.0/27") {
            $AlreadyDone ++
            $OnyxDone ++
        }
    }
    $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule | foreach {
        if ($_.SourceIp -eq "217.30.120.64/27") {
            $AlreadyDone ++
            $EDI3Done ++
        }
    }
    if ($AlreadyDone -eq 3 -and $RDG3Done -eq 1 -and $OnyxDone -eq 1 -and $EDI3Done -eq 1) {
        if ($ShowComplete) {
            Write-Host -ForegroundColor Green $EdgeGatewayGetResponseXML.EdgeGateway.name: Appears to have all Service v2 networks.
            $TotalComplete += $EdgeGateway
        }
    }

      # If no service 2 rules are found, find existing support rule and pass to the next stage
    elseif ($AlreadyDone -eq 0) {
        Write-Host -ForegroundColor Yellow $EdgeGatewayGetResponseXML.EdgeGateway.name: Does not appear to have any Service v2 networks.

        $ExistingSupportRule = $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule |
        Where-Object {$_.SourceIP -eq "81.29.64.26" -and $_.Policy -eq "allow" -and ($_.DestinationIp -eq "Any" -or $_.DestinationIp -like "internal")}
        if (!$ExistingSupportRule) {
            Write-Host -ForegroundColor Red $EdgeGatewayGetResponseXML.EdgeGateway.name: Could not find existing support rule.
            $TotalSupportRuleNonStandard += $EdgeGateway
        }
        else { $TotalToConfigure += $EdgeGateway }
    }
    else {
        Write-Host -ForegroundColor Red $EdgeGatewayGetResponseXML.EdgeGateway.name: Does not appear to have all Service v2 networks. $AlreadyDone / 3
        $TotalPartial += $EdgeGateway
    }
}

## -- Script actions start here -- ##

# Configure Edge Gateways
if ($ConfigureFirewalls -eq $true) {
    $SelectedForConfiguration = $TotalToConfigure | Out-GridView -Title "Select Edge Gateways to configure" -PassThru

    if ($SelectedForConfiguration -eq $null) {
        Write-Host -ForegroundColor Red No Edge Gateways selected. Cancelling.
        throw
    }

    foreach ($EdgeGateway in $SelectedForConfiguration) {

        Write-Host Configuring $EdgeGateway.Name
        $EdgeGatewayView = $EdgeGateway | Get-CIView

          # Set headers for Get operation
        $GetHeaders = @{
            "x-vcloud-authorization" = [string]$CIServerConnection.SessionSecret
            "Accept" = "application/*+xml;version=20.0"
        }

          # Get edge gateway details via REST
        $EdgeGatewayGetResponse = Invoke-WebRequest -Method Get -Uri $EdgeGatewayView.Href -Headers $GetHeaders
        [xml]$EdgeGatewayGetResponseXML = $EdgeGatewayGetResponse.Content
    
          # Check if changes are safe and required
        if ($EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.IsEnabled -ne $true) {
            Write-Host -ForegroundColor Red Skipping $EdgeGatewayGetResponseXML.EdgeGateway.name: Firewall is not enabled.
            continue
        }
        $ExistingSupportRule = $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule |
            Where-Object {$_.SourceIP -eq "81.29.64.26" -and $_.Policy -eq "allow" -and $_.DestinationIp -eq "Any"}
        if (!$ExistingSupportRule) {
            Write-Host -ForegroundColor Red Skipping $EdgeGatewayGetResponseXML.EdgeGateway.name: Could not find existing support rule.
            continue
        }
        $AlreadyDone = 0
        $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule | foreach {
            if ($_.SourceIp -eq "89.151.73.128/27") {
                $AlreadyDone ++
            }
        }
        if ($AlreadyDone -ne 0) {
            Write-Host -ForegroundColor Yellow Skipping $EdgeGatewayGetResponseXML.EdgeGateway.name: Appears to have already been done.
            continue
        }
    
    
        [xml]$NewRules = @'
<?xml version="1.0" encoding="UTF-8"?>
<FirewallService>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
    	<Id>1</Id>
    	<IsEnabled>true</IsEnabled>
    	<MatchOnTranslate>false</MatchOnTranslate>
    	<Description>PIIP-RDG3</Description>
    	<Policy>allow</Policy>
	    <Protocols>
	    	<Any>true</Any>
    	</Protocols>
    	<Port>-1</Port>
    	<DestinationPortRange>Any</DestinationPortRange>
	    <DestinationIp>Any</DestinationIp>
	    <SourcePort>-1</SourcePort>
    	<SourcePortRange>Any</SourcePortRange>
    	<SourceIp>89.151.73.128/27</SourceIp>
    	<EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
    	<Id>1</Id>
    	<IsEnabled>true</IsEnabled>
    	<MatchOnTranslate>false</MatchOnTranslate>
    	<Description>PIIP-Onyx</Description>
    	<Policy>allow</Policy>
    	<Protocols>
		    <Any>true</Any>
	    </Protocols>
	    <Port>-1</Port>
	    <DestinationPortRange>Any</DestinationPortRange>
	    <DestinationIp>Any</DestinationIp>
	    <SourcePort>-1</SourcePort>
	    <SourcePortRange>Any</SourcePortRange>
	    <SourceIp>195.97.223.0/27</SourceIp>
	    <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
    	<Id>1</Id>
    	<IsEnabled>true</IsEnabled>
    	<MatchOnTranslate>false</MatchOnTranslate>
    	<Description>PIIP-EDI3</Description>
    	<Policy>allow</Policy>
    	<Protocols>
		    <Any>true</Any>
	    </Protocols>
	    <Port>-1</Port>
	    <DestinationPortRange>Any</DestinationPortRange>
	    <DestinationIp>Any</DestinationIp>
	    <SourcePort>-1</SourcePort>
	    <SourcePortRange>Any</SourcePortRange>
	    <SourceIp>217.30.120.64/27</SourceIp>
	    <EnableLogging>false</EnableLogging>
    </FirewallRule>
</FirewallService>
'@

        [int]$RuleId = $ExistingSupportRule.Id

        while ($EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule.Count -gt $RuleId) {
            $Child = $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.FirewallRule[$RuleId]
            $Child = $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.RemoveChild($Child)
            $Child = $NewRules.FirewallService.OwnerDocument.ImportNode($Child, $true)
            $null = $NewRules.FirewallService.AppendChild($Child)
        }

        while ($NewRules.FirewallService.HasChildNodes) {
            $RuleId ++
            $Child = $NewRules.FirewallService.FirstChild
            $Child = $NewRules.FirewallService.RemoveChild($Child)
            $Child.Id = [string]$RuleId
            $Child = $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.OwnerDocument.ImportNode($Child, $true)
            $null = $EdgeGatewayGetResponseXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.AppendChild($Child)
        }

              # Set headers for Put operation
        $PutHeaders = @{
            "x-vcloud-authorization" = [string]$CIServerConnection.SessionSecret
            "Accept" = "application/*+xml;version=20.0"
            "Content-Type" = "application/*+xml;version=20.0"
        }

        $EdgeGatewayPutResponse = Invoke-WebRequest -Method Put -Uri $EdgeGatewayView.Href -Headers $PutHeaders -Body $EdgeGatewayGetResponseXML.InnerXml

              # Wait for operation to complete
        do {
            Start-Sleep -Seconds 5
            $EdgeGatewayTaskResponse = Invoke-WebRequest -Method Get -Uri $EdgeGatewayPutResponse.Headers.Location -Headers $GetHeaders
            [xml]$EdgeGatewayTaskResponseXML = $EdgeGatewayTaskResponse.Content
            if ($EdgeGatewayTaskResponseXML.Task.Status -match "queued" -or $EdgeGatewayTaskResponseXML.Task.Status -match "preRunning" -or $EdgeGatewayTaskResponseXML.Task.Status -match "running") {
                Write-Host -ForegroundColor DarkGreen Task status is: $EdgeGatewayTaskResponseXML.Task.Status
            } elseif ($EdgeGatewayTaskResponseXML.Task.Status -match "success") {
                Write-Host -ForegroundColor DarkGreen Task status is: $EdgeGatewayTaskResponseXML.Task.Status
            } else { Write-Host -ForegroundColor Red Task status is: $EdgeGatewayTaskResponseXML.Task.Status }
        }
        while ($EdgeGatewayTaskResponseXML.Task.Status -match "queued" -or $EdgeGatewayTaskResponseXML.Task.Status -match "preRunning" -or $EdgeGatewayTaskResponseXML.Task.Status -match "running")

    }
}
else {
    Write-Host
    Write-Host -ForegroundColor Green Total Complete: $TotalComplete.Count
    Write-Host -ForegroundColor Magenta Total Firewall Disabled: $TotalFirewallDisabled.Count
    Write-Host -ForegroundColor Yellow Total To Configure: $TotalToConfigure.Count
    Write-Host -ForegroundColor Red Total Support Rule Non Standard: $TotalSupportRuleNonStandard.Count
    Write-Host -ForegroundColor Red Total Partially Configured: $TotalPartial.Count
}

## -- Close Connections -- ##
Disconnect-CIServer