#Author: Richard Hilton
#Version: 1.1
#Purpose: Add new vCenter to vCloud Usage Meter Appliance

#Last Change by: Richard Hilton
#Status: New, tested, ready to use.
#Recommended Run Mode: Semi-automatic; Powershell ISE; Manual execution of whole script
#Changes: Fix Address issue
#Adjustments Required: None

# -- Variables start here --

#Set Variables; VMUsageMeterAppliance
$VMUsageMeterAddress = 'https://172.24.56.38:8443/um/api'
$VMusageMeterAddressvcServers = $VMUsageMeterAddress + '/vcServers'
$VMUsageMeterAddressvcServer = $VMUsageMeterAddress + '/vcServer'
#API Key can be found here: https://mist.pulsant.com/objects/view.php?oid=1368437&type=virtualserver
$APIKey = Read-Host "Enter vCloud Usage Meter API Key"

#Set Variables; vCenter to add
$vCenterPublicIP = 'set me'
$VMUsagemeterUser = 'vmusagemeter'
$VMUsagemeterPW = 'set me'

# -- Variables end here --

# -- Script actions start here --

#Set Headers
$Headers = @{
    "x-usagemeter-authorization" = "$APIKey"
    "Content-Type" = "application/xml"
}

#Build Body of request
$PostBody = @"
<vcServer xmlns="http://www.vmware.com/UM">
<hostname>$vCenterPublicIP</hostname>
<username>$VMUsagemeterUser</username>
<password>$VMUsagemeterPW</password>
<monitor>true</monitor>
</vcServer>
"@

#Use TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Allow self-signed SSL certificates
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    
    public class IDontCarePolicy : ICertificatePolicy {
        public IDontCarePolicy() {}
        public bool CheckValidationResult(
            ServicePoint sPoint, X509Certificate cert,
            WebRequest wRequest, int certProb) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy 

#Add vCenter
$PostResponse = Invoke-RestMethod -Method Post -Uri $VMUsageMeterAddressvcServer -Headers $Headers -Body $PostBody
$PostResponse.vcServer

#Get new vCenter
(Invoke-RestMethod -Method Get -Uri $VMusageMeterAddressvcServers -Headers $Headers).vcServers.vcServer |
    Where-Object -Property hostname -eq $vCenterPublicIP | ft -AutoSize hostname,username,fullname,active,meter,monitor

# -- Script actions end here --
