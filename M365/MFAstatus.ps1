$OID = '51b9efd0-8697-40b6-ad3e-be9d3a57bd1c'
$OL = 'C:\Temp\Output1.csv'
$EL = 'C:\Temp\Result1.csv'

Connect-MsolService
Connect-AzureAD
Get-AzureADGroupMember -ObjectId $OID -all $true | select UserPrincipalName | Export-Csv -force -notypeinformation -path $OL
$upns = ipcsv $OL
$upns | % {get-MsolUser -UserPrincipalName $_.UserPrincipalName} | select DisplayName,UserPrincipalName,@{Name="State"; Expression = {$_.StrongAuthenticationRequirements.State}} | Export-Csv -force -notypeinformation -path $EL

$upns | ForEach-Object { .\Get-MFAStatus -UserPrincipalName $_.UserPrincipalName }

#Get-MsolGroupMember -GroupObjectId 51b9efd0-8697-40b6-ad3e-be9d3a57bd1c | ForEach-Object { .\Get-MFAStatus -UserPrincipalName $_.UserPrincipalName }

#$users = (Get-MsolUser -UserPrincipalName james.white1@bca.com | select DisplayName,BlockCredential,UserPrincipalName,@{N="MFA Status"; E={ if( $_.StrongAuthenticationRequirements.State -ne $null){ $_.StrongAuthenticationRequirements.State} else { "Disabled"}}})