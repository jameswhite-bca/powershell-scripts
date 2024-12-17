#Title: Create vCenter Zerto Users & Permissions
#Author: Richard Hilton
#Version: 1.2
#Last Change by: Richard Hilton
#Changes: Update how password handling works, add pause for Zerto to be installed on ZVM.

# Set Variables; Passwords
# Create the following users in MIST, and enter their passwords below.
$ZertoLocalUsers = @'
Name,Password
Zerto,set me
MIST,set me
'@ | ConvertFrom-Csv

#Initialize PowerCLI
. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$False

#Connect to vCenter
Connect-VIServer localhost

#Add windows users & disable password expiry
#LEAVE ' MARKS AROUND PASSWORD! This prevents issues with passwords with $ symbols
foreach ($LocalUser in $LocalUsers) {
    [string]$ConnectionString = "WinNT://localhost,computer" 
    $ADSI = [adsi]$ConnectionString 
    $User = $ADSI.Create("user",$LocalUser.Name) 
    $User.SetPassword($LocalUser.Password) 
    $User.UserFlags = 65536 
    $User.SetInfo()
}

# Add Zerto User Permission
New-VIPermission -Entity Datacenters Zerto -Role admin

Write-Host -ForegroundColor Green "Install Zerto, then" -for
pause

# Add role & permission for MIST user
New-VIRole -Name "Zerto Read-Only" -Privilege (Get-VIPrivilege -Id zerto.com.zerto.plugin.Viewer)
New-VIPermission -Entity Datacenters MIST -Role "Zerto Read-Only"
