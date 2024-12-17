$OID = 'f589e466-df86-439f-8bb1-7cd02670eb0f'
$OL = 'C:\Temp\Output1.csv'
$EL = 'C:\Temp\Result1.csv'

Connect-MsolService
Connect-AzureAD
Get-AzureADGroupMember -ObjectId $OID -all $true | select UserPrincipalName,ObjectID | Export-Csv -force -notypeinformation -path $OL
$upns = ipcsv $OL

$upns | ForEach-Object { .\Get-MFAStatus -UserPrincipalName $_.UserPrincipalName } | Export-Csv -force -notypeinformation -path $EL

#$useroid = ipcsv $OL

#$upns | ForEach-Object { Get-AzureADUserManager -ObjectId "$useroid.ObjectID" }

Get-AzureADGroupMember -ObjectId $OID -all $true | select UserPrincipalName,@{n="Manager";e={(Get-AzureADUser -ObjectId (Get-AzureADUserManager -ObjectId $_.ObjectId).ObjectId).UserPrincipalName}} | Export-Csv C:\Temp\YOURUSERS_usr_with_manager.csv -Encoding UTF8