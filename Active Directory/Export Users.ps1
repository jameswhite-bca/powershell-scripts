$ExportPath = "$env:userprofile\Documents\ADUsers.csv"

if (!(Get-Module "ActiveDirectory")) { Import-Module ActiveDirectory}


$ADUsers = Get-ADUser -Filter * -Properties MemberOf,DisplayName,MailNickname,proxyAddresses,givenName,sn,name
$OutputData = New-Object System.Collections.ArrayList($null)

foreach ($ADUser in $ADUsers) {
    # Build OU in a more friendly format to match customer supplied documentation
    $OUdn = $ADUser.DistinguishedName.Substring($ADUser.DistinguishedName.IndexOf(",") + 1)
    $OUdn1 = $OUdn -replace '(DC\=)(.*?)(\,)', '$2.' -replace "DC=" -replace "(CN\=|OU\=)" -split ","
    [array]::Reverse($OUdn1)
    $OU = $OUdn1 -join "/"
    # Get Group Friendly Names
    $ADUserGroups = New-Object System.Collections.ArrayList($null)
    foreach ($Group in $ADUser.MemberOf) { $ADUserGroups += (Get-ADGroup $Group).Name }
    # Build and export object to Arraylist
    $OutputData += New-Object PsObject -property @{
        'Display Name' = $ADUser.DisplayName
        'Name' = $ADUser.Name
        'First Name' = $ADUser.GivenName
        'Surname' = $ADUser.Surname
        'SAMAccountName' = $ADUser.SAMAccountName
        'Alias' = $ADUser.MailNickname
        'Organizational Unit' = $OU
        'Member Of' = $ADUserGroups -join ";"
        'Primary Email' = $ADUser.ProxyAddresses -clike "SMTP:*" -replace "SMTP:" -join ";"
        'Additional Emails' = $ADUser.ProxyAddresses -clike "smtp:*" -replace "smtp:" -join ";"
        
        }
}

$OutputData | Select-Object 'Display Name', 'Name', 'First Name', 'Surname', 'SAMAccountName', 'Alias', 'Organizational Unit', 'Member Of', 'Primary Email', 'Additional Emails' | Sort-Object -Property "Display Name" | Format-Table -auto

if (Test-Path $ExportPath) { Remove-Item $ExportPath }
$OutputData | Select-Object 'Display Name', 'Name', 'First Name', 'Surname', 'SAMAccountName', 'Alias', 'Organizational Unit', 'Member Of', 'Primary Email', 'Additional Emails' | Sort-Object -Property "Display Name" | Export-Csv -NoClobber -NoTypeInformation -Path $ExportPath