#Author: Richard Hilton
#Version: 0.23
#Purpose: Upload template to vCloud catalogs
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Added GitHub
#Adjustments Required: Verification - Catalogs, OrgVdcs, Available storage

# -- Script Variables; change for every deployment --

#Set variables; Deployment target
$vCloudAddress = "cloud.pulsant.com"
$CustomerAccountCode = "PEC2" # Example: "TEST"
#$NewVMsDataInput = "CsvFile" # Options: "Script" or "CsvFile"
#$NewVMsDataInputFilePath = "C:\Users\richard.hilton\Documents\ALB\AS59 - Deploy VMs - vCloud MKN1.csv"

$Templates = @'
Name,Template,Path
Win2016,"201802-Win2016-STD-NSP","E:\VM Templates\Windows OVF\201802-Win2016-STD-NSP\201802-Win2016-STD-NSP.ovf"
Win2012R2,"201711-Win2012R2-STD-NSP","E:\VM Templates\Windows OVF\201711-Win2012R2-STD-NSP\201711-Win2012R2-STD-NSP.ovf"
Win2008R2,"201801-Win2008R2-STD-NSP","E:\VM Templates\Windows OVF\201801-Win2008R2-STD-NSP\201801-Win2008R2-STD-NSP.ovf"
CentOS7,"201802-CentOS7","E:\VM Templates\Linux OVF\201802-CentOS7\201802-CentOS7.ovf"
'@ | ConvertFrom-Csv



# -- Script Variables; change only if required --

#Set variables; Passwords
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"

# PEC2 edi3clouc2 VDC,Public Templates (edi3clouc2)
#Set variables; Definitions
$TemplateCatalogs = @'
ProviderVDC,CatalogVDC,CatalogName
edi3clouc2
mkn1clouc2
rdg3clouc2
EDI3-CLOU-V01-Core
MKN1-CLOU-V01-Core
RDG3-CLOU-V01-Core
MKN1-C1-CL1
MKN1-C2-CL1
RDG3-C1-CL1
RDG3-C2-CL1
RDG3-C3-CL1
'@ | ConvertFrom-Csv

#Generate variables; Catalog Details
foreach ($TemplateCatalog in $TemplateCatalogs) {
    $TemplateCatalog.CatalogVDC = "PEC2 " + $TemplateCatalog.ProviderVDC + " VDC"
    $TemplateCatalog.CatalogName = "Public Templates (" + $TemplateCatalog.ProviderVDC + ")"
}


# -- Open connections --

#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true -WebOperationTimeoutSeconds 3600

#Connect to vCloud
try {$vCloudConnection = Connect-CIServer -Server $vCloudAddress -Credential $vCloudCredential}
catch {throw}


# -- Verfication section --

$TemplateUploads = $Templates | Out-GridView -Passthru -Title "Select templates to upload:"
$TemplateCatalogUploads = $TemplateCatalogs | Out-GridView -Passthru -Title "Select catalogs to upload to:"

$OrgObject = Get-Org $CustomerAccountCode



# -- Script actions start here --
foreach ($TemplateCatalogUpload in $TemplateCatalogUploads) {
    $OrgVDCObject = Get-OrgVdc -Org $OrgObject -Name $TemplateCatalogUpload.CatalogVDC
    foreach ($TemplateUpload in $TemplateUploads) {
        Import-CIVAppTemplate -OrgVdc $TemplateCatalogUpload.CatalogVDC -SourcePath $TemplateUpload.Path -Catalog $TemplateCatalogUpload.CatalogName -Confirm:$false
        # Resume command:
        #Get-CIVAppTemplate -Catalog $TemplateCatalogUpload.CatalogName -Name $TemplateUpload.Template | Import-CIVAppTemplate -ResumeUpload -SourcePath $TemplateUpload.Path
    }
}

# Get-CIVAppTemplate -Catalog $TemplateCatalogUpload.CatalogName -Name "201801-Win2008R2-STD-NSP" | Import-CIVAppTemplate -ResumeUpload  -SourcePath $TemplateUpload.Path -Confirm:$false


# -- Close Connections --
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-CIServer -Server $vCloudAddress -Confirm:$false
Remove-Variable vCloudCredential
Remove-Variable vCloudConnection
