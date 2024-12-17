#Author: Paul Brazier
#Version: 0.1
#Purpose: Check storage paths for all hosts in vCenter
#Dependencies: PowerShell Version 4 or higher, PowerShell ISE, PowerCLI Version 6.5.1 or higher

#Last Change by:
#Status: Ready for testing
#Recommended Run Mode: Whole Script with PowerShell ISE
#Changes: 
#Adjustments Required: Tidy up

# -- Script Variables; change for every deployment --
$vCenterAddress = 'set me'
$esxihosts = Get-VMHost
$i=0

# -- Open connections --
#Initialize PowerCLI
$null = Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -Confirm:$False -ParticipateInCEIP $false
#Connect to vCenter
$null = Connect-VIServer -Server $vCenterAddress -ErrorAction Stop

$data = ForEach ($esxi in $esxihosts) {
    $i++
    Write-Progress -Activity "Scanning hosts" -Status ("Host: {0}" -f $esxi.Name) -PercentComplete ($i/$esxihosts.count*100) -Id 0
    $hbas = $esxi | Get-VMHostHba
    $j=0
    ForEach ($hba in $hbas) {
        $j++
        Write-Progress -Activity "Scanning HBAs" -Status ("HBA: {0}" -f $hba.Device) -PercentComplete ($j/$hbas.count*100) -Id 1
        $scsiluns = $hba | Get-ScsiLun
        $k=0
        ForEach ($scsilun in $scsiluns) {
            $k++
            Write-Progress -Activity "Scanning Luns" -Status ("Lun: {0}" -f $scsilun.CanonicalName) -PercentComplete ($k/$scsiluns.count*100) -Id 2
            $scsipaths = $scsilun | Get-Scsilunpath
            $l=0
            ForEach ($scsipath in $scsipaths) {
                $l++
                Write-Progress -Activity "Scanning Paths" -Status ("Path: {0}" -f $scsipath.Name) -PercentComplete ($l/$scsipaths.count*100) -Id 3
                New-Object PSObject -Property @{
                    Host = $esxi.name
                    HBAName = $scsilun.RuntimeName
                    PathSelectionPolicy = $scsilun.MultiPathPolicy
                    Status = $scsipath.state
                    Source = "{0}" -f ((("{0:x}" -f $hba.PortWorldWideName) -split '([a-f0-9]{2})' | where {$_}) -Join ":")
                    Target = $scsipath.SanId
                    LUN = (($scsilun.RunTimeName -Split "L")[1] -as [Int])
                    Path = $scsipath.LunPath
                }
            }
        }
    }
}

$groupdata = $data | where-object -Property hbaname -notlike "*vmhba0:*" | sort-object -Property host, LUN, Status | Group-Object host, status

foreach ($item in $groupdata) {
    $item.group | ft host, lun, status, source, target, pathselectionpolicy -AutoSize 
}
