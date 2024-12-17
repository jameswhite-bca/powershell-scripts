#Author: Richard Hilton
#Version: 0.3
#Purpose: Install Zerto

#Last Change by: Richard Hilton
#Status: New
#Changes: Tidy up and stabilisation
#Adjustments Required:

#Set variables; Passwords
# Create the following users in MIST, and enter their passwords below.
# SA (SQL), vcenter (SQL), administrator@vsphere.local, vmusagemeter, orion
$ProvisioningPW = Read-Host -Prompt "Enter provisioning password for shared.dedipower.com"

# Set variables; LocalUsers from Zerto vCenter Script; Can be pasted in from the other script
$LocalUsers = @'
Name,Password
Zerto,set me
MIST,set me
'@ | ConvertFrom-Csv

$ZertoUser = "Zerto"
$ZertoPassword = ($LocalUsers | Where-Object -Property "Name" -Match -Value $ZertoUser).Password
$ZertoPSUser = "ZertoPowershell"
$ZertoPSPassword = @'
set me
'@

# Set variables; Installer Paths
$ZertoInstaller = "\\shared.dedipower.com\Provisioning\Software\Zerto\5.5u1\Zerto_Virtual_Replication_VMware_Installer_5.5.10.269.zip"
$ZertoPSCommandsInstaller = "\\shared.dedipower.com\Provisioning\Software\Zerto\5.5u1\Zerto.PS.Commands.Installer_5.5.10.269.zip"
$ZertovSphereWebClientPluginEnablerExe = "C:\Program Files\Zerto\Zerto Virtual Replication\VsphereWebClientPluginEnabler.exe"
$ZertovSphereWebClientPluginEnablerPdb = "C:\Program Files\Zerto\Zerto Virtual Replication\VsphereWebClientPluginEnabler.pdb"


# Set variables; Zerto Installer details
$vCenterIP = "set me"
$vCenterFQDN = "set me"
$ZVMMgmtIPAddress = "set me"
$ZertoPSPort = 9080
$ZertoRestPort = 9669
$ZVMFQDN = $env:computername + ".servers.dedipower.net"
# $ZVMZertoIPAddress = "10.106.180.13"
$ZertoSiteName = "set me" # set as AccountCode-Site - eg: PROV-RDG3
$ZertoLocation = "set me" # set as Site - eg: RDG3
$ZertoContactName = "Pulsant Support"

# Set variables; Zerto Licensing
 # ZVMLIcenseType - "Local" (Installs Key) or "PartnerSite" (Does not install key)
$ZVMLicenseType = "PartnerSite"
$ZertoLicenseKey = "set me"

# Set variables; Zerto Site Peer
$ZVMPeerSiteIP = "set me"
$ZVMPeerSitePort = "9081"

# Set variables; ESXi Host details

# Example:
<#
$ESXiHosts = @'
Name,IPAddress,VRAIPAddress
INST-00000002.servers.dedipower.net,172.22.11.11,172.22.8.11
INST-00000004.servers.dedipower.net,172.22.12.11,172.22.8.12
INST-00000006.servers.dedipower.net,172.22.13.11,172.22.8.13
INST-00000008.servers.dedipower.net,172.22.14.11,172.22.8.14
'@ | ConvertFrom-Csv
#>

$ESXiHosts = @'
Name,IPAddress,VRAIPAddress

'@ | ConvertFrom-Csv

# Set variables; VRA Details
$VRADatastoreName = "set me"
$VRAGroupName = "default_group"
$VRAPortGroupName = "set me" # vCenter Portgroup Name for Zerto network
$VRAMemoryInGB = 3 # Default is 3
$VRADefaultGateway = "set me" # IP address
$VRASubnetMask = "set me" # Usually 255.255.255.0
$SecondsBetweenVRADeployments = "30"

# Set variables; vCenter Path for Web Client Plugin Enabler
$vCenterTempShare = "\\$vCenterIP\ZertoPluginEnabler"
$vCenterTempFolder = "\Pulsant\Zerto"

# Set Variables; Start-Process Function and Log locations
$stdErrLog = $env:TEMP + "\stdErr.txt"
$stdOutLog = $env:TEMP + "\stdOut.txt"
Function Show-ProcessResult {
    Get-Content -Path $stdOutLog | Write-Host -ForegroundColor Green
    echo ""
    Get-Content -Path $stdErrLog | Write-Host -ForegroundColor Red
}

# Set variables; Other
$TempDIR = "C:\Pulsant\"
$ZertoPowershellUsersFile = "C:\Program Files\Zerto\Zerto Virtual Replication\users.txt"
$ZertoPowershellUsersFileBackup = "C:\Program Files\Zerto\Zerto Virtual Replication\users.bak.txt"

# -- Script actions start here --

# Load zip/unzip Assembly
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web

# Add vCenter to Hosts file
if ((Get-Content "C:\Windows\System32\drivers\etc\hosts") -match $vCenterFQDN) {Write-Host $vCenterFQDN ":" Already Exists} else {
    $vCenterHostShortName = $vCenterFQDN.Substring(0,($vCenterFQDN.IndexOf(".")))
    $HostFileAddition = $vCenterIP + " " + $vCenterFQDN + " " + $vCenterHostShortName
    $HostFileAddition | Out-File -FilePath "C:\Windows\System32\drivers\etc\hosts" -Encoding ascii -Append
}

# Add ZVM to Hosts file
if ((Get-Content "C:\Windows\System32\drivers\etc\hosts") -match $ZVMFQDN) {Write-Host $ZVMFQDN ":" Already Exists} else {
    $ZVMHostShortName = $ZVMFQDN.Substring(0,($ZVMFQDN.IndexOf(".")))
    $HostFileAddition = $ZVMMgmtIPAddress + " " + $ZVMFQDN + " " + $ZVMHostShortName
    $HostFileAddition | Out-File -FilePath "C:\Windows\System32\drivers\etc\hosts" -Encoding ascii -Append
}

# Add ESXi Hosts to hosts file
Foreach ($ESXiHost in $ESXiHosts) {
    if ((Get-Content "C:\Windows\System32\drivers\etc\hosts") -match $ESXiHost.Name) {Write-Host $ESXiHost.Name ":" Already Exists} else {
        $ESXiHostShortName = $ESXiHost.Name.Substring(0,($ESXiHost.Name.IndexOf(".")))
        $HostFileAddition = $ESXiHost.IPAddress + " " + $ESXiHost.Name + " " + $ESXiHostShortName
        $HostFileAddition | Out-File -FilePath "C:\Windows\System32\drivers\etc\hosts" -Encoding ascii -Append
    }
}

# Open connection to shared.dedipower.com
net use \\shared.dedipower.com\Provisioning /USER:provisioning /Persistent:no $ProvisioningPW

# Copy Zerto Installer
$ZertoTempDIR = $TempDIR + "Zerto\"
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZertoInstaller, $ZertoTempDIR)
$ZertoTempInstaller = $ZertoTempDIR + (Get-ChildItem $ZertoTempDIR "*VMware*.exe" -File).Name

# Set Zerto Installer Args
$ZertoInstallerArgs = @"
-s VCenterHostName=$vCenterIP VCenterUserName=Zerto VCenterPassword=$ZertoPassword SiteExternalIP=$ZVMMgmtIPAddress SiteIpAddress=$ZVMMgmtIPAddress SiteExternalIp=$ZVMMgmtIPAddress SiteName=$ZertoSiteName SiteLocation=$ZertoLocation SiteContactInfo=$ZertoContactName
"@

# Install Zerto
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath $ZertoTempInstaller -ArgumentList $ZertoInstallerArgs
Show-ProcessResult

# Copy Zerto PS Commands Installer
$ZertoPSCommandsTempDIR = $TempDIR + "ZertoPSCommands\"
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZertoPSCommandsInstaller, $ZertoPSCommandsTempDIR)
$ZertoPSCommandsTempInstaller = $ZertoPSCommandsTempDIR + (Get-ChildItem $ZertoPSCommandsTempDIR "*.msi" -File).Name

# Set Zerto PS Commands Installer Args
$ZertoPSCommandsInstallerArgs = @"
/i $ZertoPSCommandsTempInstaller /qr
"@

# Install Zerto PS Commands
Start-Process -Wait -RedirectStandardError $stdErrLog -RedirectStandardOutput $stdOutLog -FilePath msiexec -ArgumentList $ZertoPSCommandsInstallerArgs
Show-ProcessResult

# Load Zerto PSSnapin
Add-PSSnapin Zerto.PS.Commands

# Install Zerto License
switch ($ZVMLicenseType) {
    Local {Set-License -LicenseKey $ZertoLicense -ZVMIP $ZVMMgmtIPAddress -ZVMPort $ZertoPSPort -Username "administrator" -Password "password"}
    PartnerSite {Set-Pair -PeerSiteIp $ZVMPeerSiteIP -PeerSitePort $ZVMPeerSitePort -ZVMIP $ZVMMgmtIPAddress -ZVMPort $ZertoPSPort -Username "administrator" -Password "password"}
}
Set-License -LicenseKey $ZertoLicense -ZVMIP $ZVMMgmtIPAddress -Username administrator -Password password -ZVMPort $ZertoPSPort

# Replace Zerto Powershell administrator login in users.txt
Rename-Item $ZertoPowershellUsersFile $ZertoPowershellUsersFileBackup
[Reflection.Assembly]::LoadWithPartialName("System.Web.Security")
$ZertoPSPasswordHash = [System.Web.Security.FormsAuthentication]::HashPasswordForStoringInConfigFile($ZertoPSPassword, "SHA1")
$ZertoPowershellUsersFileContent = "ZertoPowershell`t" + $ZertoPSPasswordHash
Set-Content -Path $ZertoPowershellUsersFile $ZertoPowershellUsersFileContent

# Check ZertoPowershell User Credentials & License
Get-LicenseInfo -ZVMIP $ZVMMgmtIPAddress -Username $ZertoPSUser -Password $ZertoPSPassword -ZVMPort $ZertoPSPort

# Install VRAs
# (manual)

################################################
# Configure the variables below
################################################
#$ESXiHostCSV = "C:\ZVRAPIBulkVRAScript\VRADeploymentESXiHosts.csv" # Not used
#$ZertoServer = "192.168.0.31" # Renamed to $ZVMMgmtIPAddress
#$ZertoPort = "9669" # Renamed to $ZertoRestPort
#$ZertoUser = "Zerto"
#$ZertoPassword = "Password123"
#$SecondsBetweenVRADeployments = "120"
##################################################################################
# Nothing to configure below this line - Starting the main function of the script
##################################################################################
################################################
# Setting Cert Policy - required for successful auth with the Zerto API
################################################
add-type @"
 using System.Net;
 using System.Security.Cryptography.X509Certificates;
 public class TrustAllCertsPolicy : ICertificatePolicy {
 public bool CheckValidationResult(
 ServicePoint srvPoint, X509Certificate certificate,
 WebRequest request, int certificateProblem) {
 return true;
 }
 }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

################################################
# Building Zerto API string and invoking API
################################################
$baseURL = "https://" + $ZVMMgmtIPAddress + ":"+$ZertoRestPort+"/v1/"
# Authenticating with Zerto APIs
$xZertoSessionURI = $baseURL + "session/add"
$authInfo = ("{0}:{1}" -f $ZertoUser,$ZertoPassword)
$authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
$authInfo = [System.Convert]::ToBase64String($authInfo)
$headers = @{Authorization=("Basic {0}" -f $authInfo)}
$sessionBody = '{"AuthenticationMethod": "1"}'
$contentType = "application/json"
$xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURI -Headers $headers -Method POST -Body $sessionBody -ContentType $contentType
#Extracting x-zerto-session from the response, and adding it to the actual API
$xZertoSession = $xZertoSessionResponse.headers.get_item("x-zerto-session")
$zertoSessionHeader = @{"x-zerto-session"=$xZertoSession}
# Get SiteIdentifier for getting Network Identifier later in the script
$SiteInfoURL = $BaseURL+"localsite"
$SiteInfoCMD = Invoke-RestMethod -Uri $SiteInfoURL -TimeoutSec 100 -Headers $zertoSessionHeader -ContentType "application/JSON"
$SiteIdentifier = $SiteInfoCMD | Select SiteIdentifier -ExpandProperty SiteIdentifier
$VRAInstallURL = $BaseURL+"vras"

################################################
# Importing the CSV of ESXi hosts to deploy VRA to
################################################
#$ESXiHostCSVImport = Import-Csv $ESXiHostCSV
################################################
# Starting Install Process for each ESXi host specified in the CSV
################################################
foreach ($ESXiHost in $ESXiHosts) {
    
    # Setting variables for ease of use throughout script
    $VRAESXiHostName = $ESXiHost.Name
    #$VRADatastoreName = $ESXiHost.DatastoreName
    #$VRAPortGroupName = $ESXiHost.PortGroupName
    #$VRAGroupName = $ESXiHost.VRAGroupName
    #$VRAMemoryInGB = $ESXiHost.MemoryInGB
    #$VRADefaultGateway = $ESXiHost.DefaultGateway
    #$VRASubnetMask = $ESXiHost.SubnetMask
    $VRAIPAddress = $ESXiHost.VRAIPAddress
    
    # Get NetworkIdentifier for API
    $APINetworkURL = $BaseURL+"virtualizationsites/$SiteIdentifier/networks"
    $APINetworkCMD = Invoke-RestMethod -Uri $APINetworkURL -TimeoutSec 100 -Headers $zertoSessionHeader -ContentType $ContentType
    $NetworkIdentifier = $APINetworkCMD | Where-Object {$_.VirtualizationNetworkName -eq $VRAPortGroupName} | Select -ExpandProperty NetworkIdentifier
    
    # Get HostIdentifier for API
    $APIHostURL = $BaseURL+"virtualizationsites/$SiteIdentifier/hosts"
    $APIHostCMD = Invoke-RestMethod -Uri $APIHostURL -TimeoutSec 100 -Headers $zertoSessionHeader -ContentType $ContentType
    $VRAESXiHostID = $APIHostCMD | Where-Object {$_.VirtualizationHostName -eq $VRAESXiHostName} | Select -ExpandProperty HostIdentifier
    
    # Get DatastoreIdentifier for API
    $APIDatastoreURL = $BaseURL+"virtualizationsites/$SiteIdentifier/datastores"
    $APIDatastoreCMD = Invoke-RestMethod -Uri $APIDatastoreURL -TimeoutSec 100 -Headers $zertoSessionHeader -ContentType $ContentType
    $VRADatastoreID = $APIDatastoreCMD | Where-Object {$_.DatastoreName -eq $VRADatastoreName} | Select -ExpandProperty DatastoreIdentifier
    
    # Creating JSON Body for API settings
    $JSON = "{
        ""DatastoreIdentifier"": ""$VRADatastoreID"",
        ""GroupName"": ""$VRAGroupName"",
        ""HostIdentifier"": ""$VRAESXiHostID"",
        ""HostRootPassword"":null,
        ""MemoryInGb"": ""$VRAMemoryInGB"",
        ""NetworkIdentifier"": ""$NetworkIdentifier"",
        ""UsePublicKeyInsteadOfCredentials"":true,
        ""VraNetworkDataApi"": {
            ""DefaultGateway"": ""$VRADefaultGateway"",
            ""SubnetMask"": ""$VRASubnetMask"",
            ""VraIPAddress"": ""$VRAIPAddress"",
            ""VraIPConfigurationTypeApi"": ""Static""
        }
    }"
    write-host "Executing $JSON"

    # Now trying API install cmd
    Try { Invoke-RestMethod -Method Post -Uri $VRAInstallURL -Body $JSON -ContentType $ContentType -Headers $zertoSessionHeader }
    Catch {
        Write-Host $_.Exception.ToString()
        $error[0] | Format-List -Force
    }
    
    # Waiting xx seconds before deploying the next VRA
    write-host "Waiting $SecondsBetweenVRADeployments seconds before deploying the next VRA or stopping"
    sleep $SecondsBetweenVRADeployments
}

# Close connection to shared.dedipower.com
Net use /delete \\shared.dedipower.com\Provisioning