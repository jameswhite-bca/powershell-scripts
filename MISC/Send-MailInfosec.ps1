<#
.SYNOPSIS
Send-MailInfosec sends an email to Infosec requesting that new servers are added to Hacker in a Box
.DESCRIPTION 
The script takes the hostname and IP address of the new VMs from a csv file and constructs the email. The script must be run from a server which is allowed to send email 
.PARAMETER firstname
Your firstname to include in the email
.PARAMETER emailaddress
your email address
.PARAMETER csvpath
path to the csv which contains a list of IP addresses and hostnames
.EXAMPLE
.\Send-MailInfosec.ps1 -firstname James -emailaddress james.white1@bca.com -csvpath "D:\Temp\VMBuilds.csv"
.NOTES
.LINK
=======
version : 1.0.0
last updated: 04 July 2022
Author: James White 
.LINK
https://www.bca.co.uk
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Please enter your firstname")]
    [string]$firstname,
    [Parameter(Mandatory=$True,HelpMessage="Please enter your email address")]
    [string]$emailaddress,
    [Parameter(Mandatory=$True,HelpMessage="Please provide the path to the csv file of new vms")]
    [string]$csvpath
)


$newvms = Import-Csv -Path $csvpath


$Hour = (Get-Date).Hour
If ($Hour -lt 12) 
{
    $greeting = "Good Morning"
}
elseif ( $hour -gt 12 ) 
{ 
    $greeting =  "Good Afternoon"   
}


$body = @" 
$greeting!
Please can you add the following server(s) to HIAB?
Hostname(s): $($newvms.hostname -join ", ")
IP(s): $($newvms.ipaddress -join ", ")
Domain name: ad.bca.com
Regards,
$firstname
"@

Send-MailMessage -From "$firstname <$emailaddress>" -To 'Damian Ejiogu <Damian.Ejiogu@bca.com>' `
-Cc 'IT Security <itsecurity@bca.com>' `
-Subject "Add Server(s) to HIAB" `
-Body $body `
-SmtpServer appsmtp.ad.bca.com