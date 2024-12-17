## Author: James White
## Version: 0.1
## Purpose: To configure a Veeam Backup Repository
## Dependencies: 

# Last Change by: 
# Status: Build
# Recommended Run Mode: Powershell 
# Changes: 
# Adjustments Required: 

<#
.SYNOPSIS
New-PECVeeamBackupRepo creates a new backup repository for Pulsant Enterprise Cloud
.DESCRIPTION 
New-PECVeeamBackupRepo uses Veeam Powershell comdlets to setup a new backup repository for Pulsant Enterprise Cloud following the Deployment Standard.
.PARAMETER accountcode
The account code of the customer from MIST in which to create the backup job for
.PARAMETER pecplatform
The PEC platform for deploy to. Either PEC3 or PEC4
.PARAMETER site
The site to deploy to. Can be either MKN1 or EDI3
.EXAMPLE
New-PECVeeamBackupRepo -accountcode PROV -pecplatform PEC4 -site MKN1
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,HelpMessage="Please enter the account code as display in MIST?")]
        [string]$accountcode,
        [Parameter(Mandatory=$True,HelpMessage="which PEC platform is this going onto?")]
        [ValidateSet('PEC3','PEC4')]
        [string]$pecplatform,
        [Parameter(Mandatory=$True,HelpMessage="Which site are you deploying in?")]
        [ValidateSet('MKN1','EDI3')]
        [string]$site
)
Add-PSSnapin VeeamPSSnapin

switch ( $site )
    {
        MKN1 { $path = '\\10.23.0.4\mkn1storveeam' ; $storagecreds = 'back\mkn1storgpfsauth' }
        EDI3 { $path = '\\10.25.0.4\edi3storveeam' ; $storagecreds = 'back\edi3storgpfsauth' }
    }

Add-VBRBackupRepository `
-Name $pecplatform-$accountcode-$site-BR01 `
-Folder $path\_$pecplatform\$accountcode\$pecplatform-$accountcode-$site-BR01 `
-Type CifsShare `
-credentials $storagecreds

Add-VBRScaleOutBackupRepository `
-Name $pecplatform-$accountcode-$site-SOBR `
-Extent $pecplatform-$accountcode-$site-BR01 `
-PolicyType DataLocality