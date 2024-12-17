## Author: James White
## Version: 0.1
## Purpose: To create a Virtual Datacenter on the Pulsant Enterprise Cloud following deployment standards 
## Dependencies: PowerShell Version 4 or higher

# Last Change by: James White
# Status: New
# Recommended Run Mode: run the full script from Powershell terminal or ISE
# Changes: Initial build
# Adjustments Required: 

<#
.SYNOPSIS
New-OrgVDCReservation creates a new Virtual Data Centre in an existing vCloud Organisation on the Pulsant Enterprise Cloud Platform (PEC).
.DESCRIPTION 
New-OrgVDCReservation uses VMware PowerCli with the vCloud cmdlets to create a new Virtual Data center in an existing vCloud organisation on the Pulsant Enterprise Cloud Platform (PEC). The Allocation Model is set to Reservation.
.PARAMETER accountcode
The account code of the customer from MIST in which to create the VDC.
.PARAMETER vdcname
the Name of the VDC in on PEC. Naming convention is AccountCode ClusterName VDCNumber
.PARAMETER cpu
The ammount of CPU required for the VDC in GHZ. GHz - set to native clock speed of cluster x number of vCPUs purchased (PEC2=2.9 PEC3=2.6, PEC4=2.4) then rounded up to the next integer e.g. VDC with 2 vCPU on PEC2 will be 6GHz
.PARAMETER ram
The ammount of RAM required for the VDC in GB
.PARAMETER storagegb
The ammount of storage required for the VDC in GB
.PARAMETER storageprofile
The storage profile which you would like to allocate the stroage from
.PARAMETER pecplatform
the Name of PEC platform on which you want to deploy the VDC, otherwise known as Provider VDC
.EXAMPLE
.\New-OrgVDCReservation.ps1 -accountcode PROV -vdcname 'PROV mkn1clouc2 VDC1' -cpu 5 -ram 4 -storagegb 100 -storageprofile cloumkn1c2corev2 -pecplatform mkn1clouc2 -dr False
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Enter a customer account code from MIST")]
    [string]$accountcode,
    [Parameter(Mandatory=$True,HelpMessage="Enter a name for the VDC")]
    [string]$vdcname,
    [Parameter(Mandatory=$True,HelpMessage="How much CPU do you need?")]
    [string]$cpu,
    [Parameter(Mandatory=$True,HelpMessage="How much RAM do you need?")]
    [string]$ram,
    [Parameter(Mandatory=$True,HelpMessage="How much storage do you need in GB?")]
    [int]$storagegb,
    [Parameter(Mandatory=$True,HelpMessage="Enter the Storage Profile to use")]
    [ValidateSet('clouedi3c2basev2','clouedi3c2corev2','clouedi3c3basev2','clouedi3c3corev2','cloumkn1c2basev2','cloumkn1c2corev2','cloumkn1c3basev2','cloumkn1c3corev2','clourdg3c2basev2','clourdg3c2corev2')]
    [string]$storageprofile,
    [Parameter(Mandatory=$True,HelpMessage="Which PEC platform do you want to host it on? examples mkn1clouc2, rdg3clouc2, edi3clouc2")]
    [ValidateSet('mkn1clouc2','mkn1clouc3','rdg3clouc2','edi3clouc2','edi3clouc3')]
    [string]$pecplatform,
    [Parameter(Mandatory=$False,HelpMessage="Is DR Required for this VDC?")]
    [ValidateSet($false,$true)]
    [string]$dr,
    [Parameter(Mandatory=$True,HelpMessage="Enter the Application Profile number from ACI")]
    [string]$apnumber,
    [Parameter(Mandatory=$True,HelpMessage="Enter the Endpoint group number from ACI")]
    [string]$epgnumber
)
<# 
List of Storage Profiles: 
clouedi3c2basev2,clouedi3c2corev2,clouedi3c3basev2,clouedi3c3corev2,
cloumkn1c2basev2,cloumkn1c2corev2,cloumkn1c3basev2,cloumkn1c3corev2,
clourdg3c2basev2,clourdg3c2corev2

List of PEC Platforms: 
mkn1clouc2,mkn1clouc3,rdg3clouc2,edi3clouc2,edi3clouc3
#>
[int]$storagemb = [int]$storagegb * 1024
## -- Script actions start here -- ##
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"
Write-Host -ForegroundColor Yellow "Connecting to Pulsant Enterprise Cloud"
Connect-CIServer -Server cloud.pulsant.com -Credential $vCloudCredential

Write-Host -ForegroundColor Yellow "Creating NEW OrgVDC"
  New-OrgVdc `
    -ReservationPoolModel `
    -CpuAllocationGHz $cpu `
    -MemoryAllocationGB $ram `
    -Name $vdcname `
    -Org $accountcode `
    -ProviderVdc $pecplatform `
    -StorageAllocationGB 1 `
    -NetworkPool "$accountcode|$accountcode-AP$apnumber|$accountcode-EPG$epgnumber|$pecplatform"     

# Find the Storage Profile in the Provider vDC to be added to the Org vDC  
$VDCProfile = search-cloud -QueryType ProviderVdcStorageProfile -Name $storageprofile | Get-CIView  

# Create a new object of type VdcStorageProfileParams and fill in the parameters for the new Org vDC passing in the href of the Provider vDC Storage Profile  
$spParams = new-object VMware.VimAutomation.Cloud.Views.VdcStorageProfileParams   
$spParams.Limit = $storagemb   
$spParams.Units = "MB"   
$spParams.ProviderVdcStorageProfile = $VDCProfile.href   
$spParams.Enabled = $true
$spParams.Default = $true   
  
# Create an UpdateVdcStorageProfiles object and put the new parameters into the AddStorageProfile element  
$UpdateParams = new-object VMware.VimAutomation.Cloud.Views.UpdateVdcStorageProfiles   
$UpdateParams.AddStorageProfile = $spParams   
  
# Get my test Org vDC  
$orgVdc = Get-OrgVdc -Name $vdcname
  
# Create the new Storage Profile entry in my test Org vDC  
$orgVdc.ExtensionData.CreateVdcStorageProfile($UpdateParams)  
  
## section to remove the unwanted 'default' storage porfile. 

# Get object representing the * (Any) Profile in the Org vDC  
$orgvDCAnyProfile = search-cloud -querytype AdminOrgVdcStorageProfile | where {($_.VdcName -eq $orgvDC.Name) -and ($_.Name -notlike $storageprofile)}  | Get-CIView  
  
# Disable the "* (any)" Profile  
$orgvDCAnyProfile.Enabled = $False  
$result = $orgvDCAnyProfile.UpdateServerData() 
  
# Remove the "* (any)" profile form the Org vDC completely  
$ProfileUpdateParams = new-object VMware.VimAutomation.Cloud.Views.UpdateVdcStorageProfiles  
$ProfileUpdateParams.RemoveStorageProfile = $orgvDCAnyProfile.href  
$orgvDC.extensiondata.CreatevDCStorageProfile($ProfileUpdateParams)

# Enabling Thin Provisioning and Setting Maximum Networks to 3
Write-Host -ForegroundColor Yellow "Changing settings according to Deployment Standards"
get-orgvdc -Name $vdcname | Set-OrgVdc -ThinProvisioned $true -NetworkMaxCount 3

# Adding default vApp(s) to the new VDC
Write-Host -ForegroundColor Yellow "Adding default vApp(s) to the new VDC"
New-CIVApp -OrgVdc $vdcname -Name "$vdcname servers"

If ($dr -eq $true) {
New-CIVApp -OrgVdc $vdcname -Name "$vdcname zerto"
}

## -- Close Connections -- ##
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-CIServer -Server cloud.pulsant.com -Confirm:$false
Remove-Variable accountcode
Remove-Variable vdcname
Remove-Variable cpu
Remove-Variable ram
Remove-Variable storagemb
Remove-Variable storageprofile
Remove-Variable pecplatform
Remove-Variable result