#Author: Richard Hilton
#Version: 0.14
#Purpose: Show information about vCloud Org VDCs.
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Add Org VDC list and Org Catalog list
#Adjustments Required:


# -- Script Variables; change for every deployment --

#Set variables; Deployment target
$vCloudAddress = "cloud.pulsant.com"
# $CustomerAccountCode = "set me" # Example: "TEST"


# -- Script Variables; change only if required --

#Set variables; Passwords
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"
$CustomerAccountCode = Read-Host "Enter Customer Account Code"


# -- Open connections --

#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true

#Connect to vCloud
try {$vCloudConnection = Connect-CIServer -Server $vCloudAddress -Credential $vCloudCredential}
catch {throw}


# -- Gather information --

# Get Org
$Org = Get-Org -Name $CustomerAccountCode -ErrorAction Stop
$OrgObjectID = $Org.ID

Write-Host -ForegroundColor Green Details for $Org.Name org

# Get OrgVDCs
Write-Host -ForegroundColor Green Org VDCs
Get-OrgVdc -Org $Org
# Search-Cloud -QueryType AdminOrgVdc -Filter "Org==$OrgObjectID" | ft @{Name="Org VDC";Expression={$_."Name"}} -AutoSize


# Get OrgVDCs and their Catalogs
Write-Host -ForegroundColor Green Catalogs
Get-Catalog -Org $Org | ft Name -AutoSize


# Get OrgVDCs and their vApps
Write-Host -ForegroundColor Green vApps
Search-Cloud -QueryType AdminVApp -Filter "Org==$OrgObjectID" | ft @{Name="Org VDC";Expression={$_."VdcName"}}, @{Name="vApp";Expression={$_."Name"}} -AutoSize

# Get OrgVDCs and their Networks
Write-Host -ForegroundColor Green Org VDC Networks
$Script:OrgVDCNetworks = @()
foreach ($OrgVDC in (Get-OrgVDC -Org $Org)) {
    $Script:OrgVDCNetworks += Get-OrgVdcNetwork -OrgVdc $OrgVDC | select OrgVdc,Name,DefaultGateway
}
$Script:OrgVDCNetworks | ft @{Name="Org VDC";Expression={$_."OrgVdc"}}, @{Name="Org VDC Network Name";Expression={$_."Name"}}, DefaultGateway -AutoSize

# Get vApps and their Networks
Write-Host -ForegroundColor Green vApp Networks
Search-Cloud -QueryType AdminVAppNetwork -Filter "Org==$OrgObjectID" | ft @{Name="vApp";Expression={$_."VAppName"}}, @{Name="vApp Network";Expression={$_."Name"}} -AutoSize

# Get OrgVDCs and their Storage Policies
Write-Host -ForegroundColor Green Storage policies
Search-Cloud -QueryType AdminOrgVdcStorageProfile -Filter "Org==$OrgObjectID" | ft @{Name="Org VDC";Expression={$_."VdcName"}}, @{Name="Storage Policy";Expression={$_."Name"}} -AutoSize

# -- Close Connections --
Disconnect-CIServer -Server $vCloudAddress -Confirm:$false
