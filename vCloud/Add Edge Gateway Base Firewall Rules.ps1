## Author: Richard Hilton
## Version: 0.1
## Purpose: Add base edge gateway firewall rules
## Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI

# Last Change by: Richard Hilton
# Status: New
# Recommended Run Mode: Whole Script with PowerShell ISE
# Changes: Create save config folder if does not exist
# Adjustments Required: 

## -- Script Variables; check and/or change for every deployment -- ##

$EdgeGatewayName = "set me"

## -- Script Variables; change only if required -- ##

# Standard Rules
[xml]$NewRules = @'
<?xml version="1.0" encoding="UTF-8"?>
<FirewallService>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>1</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Outbound Any</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Any>true</Any>
        </Protocols>
        <Port>-1</Port>
        <DestinationPortRange>Any</DestinationPortRange>
        <DestinationIp>external</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>internal</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>2</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>RDG Support Access</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Any>true</Any>
        </Protocols>
        <Port>-1</Port>
        <DestinationPortRange>Any</DestinationPortRange>
        <DestinationIp>Any</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>81.29.64.26</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>3</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Monitoring</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Any>true</Any>
        </Protocols>
        <Port>-1</Port>
        <DestinationPortRange>Any</DestinationPortRange>
        <DestinationIp>Any</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>81.29.64.227-81.29.64.245</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>4</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Backups1</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Tcp>true</Tcp>
        </Protocols>
        <Port>1167</Port>
        <DestinationPortRange>1167</DestinationPortRange>
        <DestinationIp>internal</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>81.29.95.32/28</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>5</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Backups2</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Tcp>true</Tcp>
        </Protocols>
        <Port>1167</Port>
        <DestinationPortRange>1167</DestinationPortRange>
        <DestinationIp>internal</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>89.151.65.0/26</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>6</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Backups3</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Tcp>true</Tcp>
        </Protocols>
        <Port>1167</Port>
        <DestinationPortRange>1167</DestinationPortRange>
        <DestinationIp>internal</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>202.170.0.72</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>7</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Orion1</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Any>true</Any>
        </Protocols>
        <Port>-1</Port>
        <DestinationPortRange>Any</DestinationPortRange>
        <DestinationIp>Any</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>46.236.30.90</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>8</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Orion2</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Any>true</Any>
        </Protocols>
        <Port>-1</Port>
        <DestinationPortRange>Any</DestinationPortRange>
        <DestinationIp>Any</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>46.249.219.90</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>9</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>Orion3</Description>
        <Policy>allow</Policy>
        <Protocols>
            <Any>true</Any>
        </Protocols>
        <Port>-1</Port>
        <DestinationPortRange>Any</DestinationPortRange>
        <DestinationIp>Any</DestinationIp>
        <SourcePort>-1</SourcePort>
        <SourcePortRange>Any</SourcePortRange>
        <SourceIp>46.249.207.90</SourceIp>
        <EnableLogging>false</EnableLogging>
    </FirewallRule>
    <FirewallRule xmlns="http://www.vmware.com/vcloud/v1.5">
        <Id>10</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>PIIP-RDG3 Pulsant Service V2 Reading</Description>
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
        <Id>11</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>PIIP-Onyx Pulsant Service V2 Onyx</Description>
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
        <Id>12</Id>
        <IsEnabled>true</IsEnabled>
        <MatchOnTranslate>false</MatchOnTranslate>
        <Description>PIIP-EDI3 Pulsant Service V2 Edinburgh</Description>
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

## -- Open connections -- ##

if (!$CIServerConnection) { $CIServerConnection = Connect-CIServer cloud.pulsant.com -ErrorAction Stop }
elseif ($CIServerConnection.IsConnected -ne $true) { $CIServerConnection = Connect-CIServer cloud.pulsant.com -ErrorAction Stop } 

## -- Verfication section -- ##

if ($CIServerConnection.IsConnected -ne $true) {throw "vCloud Connection Failed"}

$EdgeGateway  = Search-Cloud -QueryType EdgeGateway -Name $EdgeGatewayName

$EdgeGateway = $EdgeGateway | Out-GridView -Title "Select Edge Gateways to reset firewall rules" -PassThru

if ($null -eq $EdgeGateway) {
    Write-Host -ForegroundColor Red No Edge Gateways selected. Cancelling.
    throw
}

$EdgeGatewayView = $EdgeGateway | Get-CIView

    # Set headers for Get operation
$GetHeaders = @{
    "x-vcloud-authorization" = [string]$CIServerConnection.SessionSecret
    "Accept" = "application/*+xml;version=20.0"
}

    # Get edge gateway details via REST
$EdgeGatewayGetResponse = Invoke-WebRequest -Method Get -Uri $EdgeGatewayView.Href -Headers $GetHeaders
[xml]$EdgeGatewayGetResponseXML = $EdgeGatewayGetResponse.Content

while ($NewRules.FirewallService.HasChildNodes) {
    $Child = $NewRules.FirewallService.FirstChild
    $Child = $NewRules.FirewallService.RemoveChild($Child)
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


## -- Close Connections -- ##
Disconnect-CIServer