## Author: James White
## Version: 0.2
## Purpose: to create a new Org on vCloud
## Dependencies: PowerShell Version 4 or higher

# Last Change by: James White
# Status: New
# Recommended Run Mode: run the full script from Powershell terminal or ISE
# Changes: Initial build
# Adjustments Required:

<#
.SYNOPSIS
New-Org creates a new customer vCloud organisation on the Pulsant Enterprise Cloud Platform (PEC).
.DESCRIPTION 
New-Org uses VMware PowerCli with the vCloud cmdlets to create a new customer account on the Pulsant Enterprise Cloud Platform (PEC)
.PARAMETER accountcode
The account code of the customer in MIST to create on vCloud.
.PARAMETER fullname
The full Organisation Name as displayed in MIST
.PARAMETER adminpassword
The password for the admin user for customer access
.PARAMETER description
The description of the Organisation. This parameter is optional
.EXAMPLE
.\New-Org.ps1 -accountcode JT01 -fullname "JT01 - James Test company ltd" -adminpassword 'Pa$$w0rd' -description "This is James White's test company"
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Enter a customer account code from MIST")]
    [string]$accountcode,
    [Parameter(Mandatory=$True,HelpMessage="Enter the full Organisation Name from MIST")]
    [string]$fullname,
    [Parameter(Mandatory=$True,HelpMessage="Enter a password for the customer admin user")]
    [string]$adminpassword,
    [Parameter(Mandatory=$False)]
    [string]$description
)
## -- Script actions start here -- ##
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"
Write-Host -ForegroundColor Yellow "Connecting to Pulsant Enterprise Cloud"
Connect-CIServer -Server cloud.pulsant.com -Credential $vCloudCredential

Write-Host -ForegroundColor Yellow "Creating NEW Org on PEC"
New-Org -Name $accountcode -FullName $fullname -Description $description

$org = Get-Org -Name $accountcode

Write-Host -ForegroundColor Yellow "Setting Org Policies"
# Set vApp lease times
$leases = $org.ExtensionData.Settings.GetVAppLeaseSettings()
$leases.DeploymentLeaseSeconds = 000000
$leases.StorageLeaseSeconds = 00000000
$leases.DeleteOnStorageLeaseExpiration = $False
$leases.UpdateServerData()
 
# Set vApp template lease times
$templateleases = $org.ExtensionData.Settings.GetVAppTemplateLeaseSettings()
$templateleases.StorageLeaseSeconds = 00000000
$templateleases.DeleteOnStorageLeaseExpiration = $False
$templateleases.UpdateServerData()

Write-Host -ForegroundColor Yellow "Creating Customer Admin User"
#create user section

$role = search-cloud -querytype AdminRole | where {($_.OrgName -eq $accountcode) -and ($_.Name -eq "Organization Administrator")} | Get-CIView

$user = New-Object VMware.VimAutomation.Cloud.Views.User

$user.Name ="$org.admin"
$user.Password = $adminpassword
$user.Role = $role.id
$user.IsEnabled = $true

$org.ExtensionData.createUser($user)

## -- Close Connections -- ##
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-CIServer -Server cloud.pulsant.com -Confirm:$false
Remove-Variable accountcode
Remove-Variable fullname
Remove-Variable description
Remove-Variable role
Remove-Variable adminpassword
Remove-Variable user
Remove-Variable org