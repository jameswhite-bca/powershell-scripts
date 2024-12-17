# Import the PowerCLI module
Import-Module VMware.VimAutomation.Core -ErrorAction SilentlyContinue
#variables
$vCenterAddress = 'pd-vcent-001.ad.bca.com'
$IP = '192.168.116.199'
$SNM = '255.255.255.0'
$GW = '192.168.116.240'
$DNS1 = '192.168.117.100'
$DNS2 = '192.168.117.101'

#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $true
#Connect to vCenter and provide domain credentials
$domaincreds = (Get-Credential -Message 'Enter your domain credentials')
if (!$vCenterConnection) { $vCenterConnection = Connect-VIServer -Server $vCenterAddress -Force -ErrorAction Stop -Credential $domaincreds }
elseif ($vCenterConnection.IsConnected -ne $true) { $vCenterConnection = Connect-VIServer -Server $vCenterAddress -Force -ErrorAction Stop -Credential $domaincreds}
#local admin password
$localadminpwd = (Get-Credential -Message 'Enter the local admin password to the VMs' -UserName administrator)
#choose template name you wish to update
$TemplateVMName="winserver2019testtemplate"
#Convert a template to a VM
Set-Template -Template $TemplateVMName -ToVM
#Make a 60 seconds delay
Start-sleep -s 60
#Start the virtual machine
Start-VM -VM $TemplateVMName | Get-VMQuestion | Set-VMQuestion -DefaultOption
Start-sleep -s 120
#set to right network in VCenter
get-vm $TemplateVMName | get-networkadapter | set-networkadapter -Portgroup  dvPG_UK_Prod_192.168.116.0 -Confirm:$false
#set network config locally
$Network = Invoke-VMScript -VM $templateVMName -ScriptType Powershell -ScriptText "(gwmi Win32_NetworkAdapter -filter 'netconnectionid is not null').netconnectionid" -GuestUser administrator -GuestPassword $localadminpwd.getnetworkcredential().password 
$NetworkName = $Network.ScriptOutput
$NetworkName = $NetworkName.Trim()
Write-Host "Setting IP address for $templateVMname..." -ForegroundColor Yellow
start-Sleep -Seconds 60
$netsh = @"
netsh interface ip set address "$NetworkName" static $IP $SNM $GW
netsh interface ip set dnsservers "$NetworkName" static $DNS1 primary 
netsh interface ip add dnsservers "$NetworkName" $DNS2
"@
$setnetwork = Invoke-VMScript -VM $templateVMname -Guestuser administrator -guestpassword  $localadminpwd.getnetworkcredential().password -ScriptType bat -ScriptText $netsh
$setnetwork
write-host $setnetwork.ScriptOutput
Write-Host "Setting IP address completed." -ForegroundColor Green
Restart-VMGuest -VM $TemplateVMName
# Run the command to install all available updates in the guest OS using VMWare Tools (the update installation log is saved to a file: C:\temp\Update.log)
write-host "installing windows updates this may take a while"
start-sleep -s 60
$installwinupdate = Invoke-VMScript -ScriptType PowerShell -ScriptText "Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot" -VM $TemplateVMName -Guestuser administrator -guestpassword  $localadminpwd.getnetworkcredential().password
$installwinupdate
write-host $installwinupdate.ScriptOutput
Write-Output $installwinupdate.ScriptOutput >> C:\temp\windowsupdate.txt
Start-sleep -s 180
#check windows updates are installed
invoke-vmscript -vm $TemplateVMName -GuestUser administrator -GuestPassword $localadminpwd.GetNetworkCredential().Password -ScriptType Powershell -ScriptText Get-Hotfix
# Update VMTools
Update-Tools -VM $TemplateVMName -NoReboot
# Clean up the WinSxS component store and optimize the image with DISM
Invoke-VMScript -ScriptType PowerShell -ScriptText "Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase" -VM $TemplateVMName -Guestuser administrator -guestpassword  $localadminpwd.getnetworkcredential().password
Start-sleep -s 60
# Force restart the VM
Restart-VMGuest -VM $TemplateVMName
#Shut the VM down and convert it back to the template
Start-sleep -s 60
Stop-VMGuest -VM $TemplateVMName -Confirm:$False
Start-sleep -s 60
Set-VM $TemplateVMName -ToTemplate -Confirm:$False