Connect-MsolService


$upns = ipcsv "C:\Users\whiteja\OneDrive - British Car Auctions - Europe\Desktop\Scripts\mfa.csv"


$sar = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement


$sar.RelyingParty = "*"


$sar.State = 'Enabled'


$mfa = @($sar)


$upns | % {Set-MsolUser -StrongAuthenticationRequirements $mfa -UserPrincipalName $_.upn}


$upns | % {get-MsolUser -UserPrincipalName $_.upn} | select DisplayName,UserPrincipalName,@{Name="State"; Expression = {$_.StrongAuthenticationRequirements.State}}