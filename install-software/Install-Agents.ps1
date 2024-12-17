<#
.SYNOPSIS
Install-Agents installs the standard BCA agents onto a computer
.DESCRIPTION 
The script takes a list of hostnames from the standard BCA vmbuilds.csv file and install the software. The software installers are first copied to the c drive of the servers
.PARAMETER csvpath
path to the csv which contains a list of hostnames
.PARAMETER source
path to the source folder which contains the installers
.PARAMETER reboot
would you you like to reboot the servers after installation
.EXAMPLE
.\Install-Agents.ps1 -csvpath "D:\Temp\VMBuilds.csv -reboot True"
.NOTES
.LINK
=======
version : 1.0.0
last updated: 11 July 2022
Author: James White 
.LINK
https://www.bca.co.uk
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Please provide the path to the csv file of vms")]
    [string]$csvpath,
	[Parameter(Mandatory=$False,HelpMessage="Would you like to reboot after the installation?")]
    [ValidateSet($false,$true)]
	[string]$reboot
)

$Servers = (Import-Csv -Path $csvpath)

$source = "\\hd-2k8-fs01\Software\ICESoftwarePackage"

$creds = (get-credential -Message 'Enter your BCA $ Account')                

foreach ($Server in $Servers)
{
    if (test-Connection -Cn $Server.hostname -quiet)
	{
		New-PSDrive -Name Y -PSProvider filesystem -Root \\$($Server.hostname)'\C$\Software' -Credential $creds
		Copy-Item $source -Destination Y:\ -Recurse -ErrorAction SilentlyContinue -ErrorVariable A
		if($A) { write-Output "$Server - File copy Failed" | out-file "C:\temp\FileTransfer.txt" -Append }
		Remove-PSDrive Y
	}
	else
	{	Write-Output "$Server is offline" | Out-File "C:\temp\Copy_error.txt" -Append}

    Invoke-Command -ComputerName $Server.hostname -ScriptBlock {Start-Process msiexec.exe -Wait -ArgumentList '/I "C:\Software\ICESoftwarePackage\BCA-UK_snowagent-6.7.1\BCA-UK_snowagent-6.7.1.x64.msi" /quiet'} -Credential ($creds)
    Invoke-Command -ComputerName $Server.hostname -ScriptBlock {Start-Process msiexec.exe -Wait -ArgumentList '/I "C:\Software\ICESoftwarePackage\Redcloak\redcloak.msi" /quiet'} -Credential ($creds)
    Invoke-Command -ComputerName $Server.hostname -ScriptBlock {Start-Process -Wait -FilePath "C:\Software\ICESoftwarePackage\Symantec Endpoint Protection version 14.3.5427.3000 - English\setup.exe"} -Credential ($creds)
    
	if ( $reboot = $true )
	{
    Invoke-Command -ComputerName $Server.hostname -ScriptBlock {Restart-Computer -Force} -Credential ($creds)
	}
}