$DaysInactive = 90
$time = (Get-Date).Adddays(-($DaysInactive))

#$AllServers=Get-ADComputer -Filter {LastLogonDate -gt $time -and OperatingSystem -Like "Windows Server*" -and Enabled -eq 'True'}
$AllServers=Get-ADComputer -Filter {OperatingSystem -Like "Windows Server*" -and Enabled -eq 'True'}
$Servers = ForEach ($Server in $AllServers){
  
  $Result=Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" -Property DNSServerSearchOrder -ComputerName $Server.Name 
  
  New-Object -TypeName PSObject -Property @{
    ComputerName = $Server.Name -join ','
    DNSServerSearchOrder = $Result.DNSServerSearchOrder -join ','
  
  } | Select-Object ComputerName,DNSServerSearchOrder | Export-Csv -Path C:\Temp\InternalServerDNSSettings.csv -NoTypeInformation -Append
}


