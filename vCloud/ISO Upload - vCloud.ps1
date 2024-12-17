#Author: Richard Hilton
#Version: 0.13
#Purpose: Upload ISO to vCloud catalogs
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by: Richard Hilton
#Status: New
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: Add # Check if IP address matches network specification
#Adjustments Required:

# -- Script Variables; change for every deployment --

#Set variables; Deployment target
$vCloudAddress = "cloud.pulsant.com"
$CustomerAccountCode = "set me" # Example: "TEST"
$vdcName = "set me"
$catalogName = "set me"
#Example: $ISOs = "C:\Users\<username>\Downloads\SLES-11-SP4-DVD.ISO","C:\Users\<username>\Downloads\osbiz_v2_R2.1.0.iso"
$ISOs = "set me","set or delete me"


# -- Open connections --

#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true -WebOperationTimeoutSeconds 3600

#Connect to vCloud
try {$vCloudConnection = Connect-CIServer -Server $vCloudAddress -Credential $vCloudCredential}
catch {throw}


# -- Script Variables; change only if required --

#Set variables; Passwords
$vCloudCredential = Get-Credential -Message "Enter your vCloud Credentials"


# -- Verfication section --


# -- Script actions start here --
$OrgObject = Get-Org $CustomerAccountCode

foreach ($ISO in $ISOs) {

    #Create vCloud Objects
    $ISOObject = Get-Item $ISO

    $media = New-Object VMware.VimAutomation.Cloud.Views.Media
    #$test = New-Object VMware.VimAutomation.Cloud.Views.VAppTemplate
    $media.name = $ISOObject.name
    $media.ImageType = 'iso'
    $media.size = $ISOObject.length

    $media.Files = New-Object VMware.VimAutomation.Cloud.Views.FilesList
    $media.Files.File = @(new-object VMware.VimAutomation.Cloud.Views.File)
    $media.Files.File[0] = new-object VMware.VimAutomation.Cloud.Views.File
    $media.Files.file[0].type = 'iso'
    $media.Files.file[0].name = $ISOObject.name

    $vdc = Get-OrgVdc $vdcName
    $vdc.ExtensionData.CreateMedia($media)

    #Do Upload
    $filehref = (Get-Media $media.name | Get-CIView).files.file[0].link[0].href
    $Timeout=10000000
    $bufSize=10000


    $webRequest = [System.Net.HttpWebRequest]::Create($filehref)
    $webRequest.Timeout = $timeout
    $webRequest.Method = "PUT"
    $webRequest.ContentType = "application/data"
    $webRequest.AllowWriteStreamBuffering=$false
    $webRequest.SendChunked=$true # needed by previous line

    $requestStream = $webRequest.GetRequestStream()
    $fileStream = [System.IO.File]::OpenRead($ISOObject)
    $chunk = New-Object byte[] $bufSize
    while( $bytesRead = $fileStream.Read($chunk,0,$bufsize) )
    {
        $requestStream.write($chunk, 0, $bytesRead)
        $requestStream.Flush()
    }

    $responceStream = $webRequest.getresponse()
    $status = $webRequest.statuscode

    $FileStream.Close()
    $requestStream.Close()
    $responceStream.Close()

    $responceStream
    $responceStream.GetResponseHeader("Content-Length")
    $responceStream.StatusCode
    $status
}

# Get-CIVAppTemplate -Catalog $TemplateCatalogUpload.CatalogName -Name "201801-Win2008R2-STD-NSP" | Import-CIVAppTemplate -ResumeUpload  -SourcePath $TemplateUpload.Path -Confirm:$false


# -- Close Connections --
Write-Host -ForegroundColor Green "Script complete, closing connections."
Disconnect-CIServer -Server $vCloudAddress -Confirm:$false
Remove-Variable vCloudCredential
Remove-Variable vCloudConnection
