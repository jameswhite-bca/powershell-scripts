## Author: James White
## Version: 0.1
## Purpose: To configure a Veeam backup job
## Dependencies: 

# Last Change by: 
# Status: Build
# Recommended Run Mode: Powershell 
# Changes: 
# Adjustments Required: 

<#
.SYNOPSIS
.DESCRIPTION 
.PARAMETER accountcode
The account code of the customer from MIST in which to create the backup job for
.PARAMETER pecplatform
The PEC platform for deploy to. Either PEC3 or PEC4
.PARAMETER site
The site to deploy to. Can be either MKN1 or EDI3
.PARAMETER vcloudentity
Enter either the vAPP, VDC or VM name you want to backup
.PARAMETER vdcnumber
enter the VDC number e.g. 1 or 2 if they have more than one VDC
.PARAMETER jobnamesuffix
Enter a suffix for the job name like VMs or vApp1 for example
.PARAMETER daily
Do you want the job to run everyday or on selected days
.PARAMETER days
input the days in which you want the job to run on e.g. Tuesday or Thursday you can select multiple days using a comma separator
.PARAMETER time
What time should the job run at. Uses 24 hour clock. The default is 22:00
.EXAMPLE
.\New-PECVeeamBackup.ps1 -accountcode PROV -pecplatform PEC4 -site MKN1 -vcloudentity 'PROV mkn1clouc2 VDC1' -vdcnumber 1 -jobnamesuffix VDCBackup -Daily True
.EXAMPLE
.\New-PECVeeamBackup.ps1 -accountcode PROV -pecplatform PEC4 -site EDI3 -vcloudentity "Ajay-PS-Source" -vdcnumber 1 -jobnamesuffix VMBackup -daily False -days Friday,Saturday,Tuesday
.EXAMPLE
.\New-PECVeeamBackup.ps1 -accountcode PROV -pecplatform PEC3 -site EDI3 -vcloudentity "PS TEST Deployment" -vdcnumber 1 -jobnamesuffix vAppBackup -daily True -time 15:57
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Please enter the account code as display in MIST")]
    [string]$accountcode,
    [Parameter(Mandatory=$True,HelpMessage="which pec platform is this going onto")]
    [ValidateSet('PEC3','PEC4')]
    [string]$pecplatform,
    [Parameter(Mandatory=$True,HelpMessage="Which site are you deploying in")]
    [ValidateSet('MKN1','EDI3')]
    [string]$site,
    [Parameter(Mandatory=$True,HelpMessage="Enter either the vAPP, VDC or VM name you want to backup")]
    [string]$vcloudentity,
    [Parameter(Mandatory=$True,HelpMessage="enter the VDC number e.g. 1 or 2 if they have more than one VDC")]
    [string]$vdcnumber,
    [Parameter(Mandatory=$True,HelpMessage="Enter a suffix for the job name like VMs or vApp1 for example")]
    [string]$jobnamesuffix,
    [Parameter(Mandatory=$True,HelpMessage="Enter whether you want the job to run daily or on selected days")]
    [ValidateSet($true,$false)]
    [string]$daily,
    [Parameter(Mandatory=$False,HelpMessage="Enter the day(s) in which you want the job run on")]
    [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
    [string[]]$days,
    [Parameter(Mandatory=$False,HelpMessage="Enter a time for the job to run at in 24 hour format e.g. 19:00. Default value is 22:00")]
    [string]$time = '22:00'
)

Add-PSSnapin VeeamPSSnapin

Find-VBRvCloudEntity `
-Name $vcloudentity | Add-VBRvCloudJob -Name $pecplatform-$accountcode-$site-VDC0$vdcnumber-$jobnamesuffix `
-BackupRepository $pecplatform-$accountcode-$site-SOBR

Enable-VBRJobSchedule `
-Job $pecplatform-$accountcode-$site-VDC0$vdcnumber-$jobnamesuffix

If ($daily -eq $true) {

Set-VBRJobSchedule `
-Job $pecplatform-$accountcode-$site-VDC0$vdcnumber-$jobnamesuffix `
-Daily `
-At $time `
-DailyKind Everyday
     
} ElseIf ($daily -eq $false) {

Set-VBRJobSchedule `
-Job $pecplatform-$accountcode-$site-VDC0$vdcnumber-$jobnamesuffix `
-Days $days `
-DailyKind SelectedDays `
-At $time `

}