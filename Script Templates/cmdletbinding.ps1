<#
.SYNOPSIS
.DESCRIPTION 
.PARAMETER variable1
.PARAMETER variable2
.PARAMETER variable3
.EXAMPLE
.NOTES
<<<<<<< HEAD
version :
last updated:
Author:
.LINK
=======
version : 1.0.0
last updated: 28 April 2021
Author: 
.LINK
https://www.example.com
>>>>>>> 209d4ebf86ab3d8894485eb48eac98839a946d89
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [string]$variable1,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [int]$variable2,
    [Parameter(Mandatory=$True,HelpMessage="How can I help you?")]
    [ValidateSet('server1','server2','server3')]
    [string]$variable3
)