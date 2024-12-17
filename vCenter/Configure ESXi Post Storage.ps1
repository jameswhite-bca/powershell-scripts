#Author: Richard Hilton
#Version: 0.42
#Last Change by: Richard Hilton
#Changes: New script

#Status: New
#Recommended Run Mode: Semi-automatic; Powershell ISE; Manual execution of whole script
#Adjustments Required:

# Set Variables; vCenter
$vCenterAddress = "localhost"

# Set Variables; ESXi Hosts
# FQDNs of ESXi Hosts to Configure, and passwords
# Example:
# $ESXiHosts @'
# Name,LocalStorage,Patch,ExitMaintenanceMode
# inst-00000001.servers.dedipower.net,No,Yes,Yes
# inst-00000002.servers.dedipower.net,No,Yes,Yes
# inst-00000003.servers.dedipower.net,No,Yes,Yes
# '@ | ConvertFrom-Csv

$ESXiHosts = @'
Name,LocalStorage,Patch,ExitMaintenanceMode

'@ | ConvertFrom-Csv


#Set Variables; Passwords
$ProvisioningPW = Read-Host -Prompt "Enter Provisioning user password for shared.dedipower.com"

# Set variables; Installer Paths
$DellOpenmanageInstallPath = "\\shared.dedipower.com\Provisioning\Software\Dell\OpenManage\ESXi 6.5 VIB\OM-SrvAdmin-Dell-Web-8.5.0-2372.VIB-ESX65i_A00.zip"

# Set variables; Scratch datastore
$ScratchDatastore = "set me"

#Set Variables; Other
$TempDIR = "D:\Pulsant\"

#Functions; Enter-MaintenenceMode
Function Enter-MaintenenceMode ($CurrentServer) {

    # Get Server Object
    $CurrentServer = Get-VMHost $CurrentServer

    # Check if already in maintenence mode, set if not
    if ((Get-VMHost $CurrentServer).ConnectionState -notmatch "Maintenance") {
        if ( (Get-Cluster | Get-VMHost).Name -match $CurrentServer ) { Set-VMHost $CurrentServer -State Maintenance -Evacuate }
        else { Set-VMHost $CurrentServer -State Maintenance }
    }
}

# -- Functions --
function WaitFor-VMHostRebootStart {
    do {
        Write-Host "Waiting for" $ESXiHost.Name "to begin reboot"
        sleep 15
        $ESXiHostState = (Get-VMHost $ESXiHost.Name).ConnectionState
    }
        while ($ESXiHostState -ne "NotResponding")
}

function WaitFor-VMHostRebootFinish {
    $ESXiHostState = (Get-VMHost $ESXiHost.Name).ConnectionState
    if ($ESXiHostState -ne "Maintenance" -and $ESXiHostState -ne "Connected") {
        do {
            Write-Host "Waiting for" $ESXiHost.Name "to complete reboot"
            sleep 30
            $ESXiHostState = (Get-VMHost $ESXiHost.Name).ConnectionState
        }
        while ($ESXiHostState -ne "Maintenance" -and $ESXiHostState -ne "Connected")
    }
}


# -- Open connections --

# Initialize PowerCLI
Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Single -ParticipateInCEIP $true -WebOperationTimeoutSeconds 900 -Confirm:$False

# Open connection to vCenter
Connect-VIServer $vCenterAddress

# Open connection to shared.dedipower.com
net use \\shared.dedipower.com\Provisioning /USER:provisioning /Persistent:no $ProvisioningPW


# -- Script verification starts here --

# Initialize error counter
$ErrorCount = 0

# Create TempDIR if it doesn't exist
if (!(Test-Path $TempDIR -ErrorAction SilentlyContinue)) { md $TempDIR }

# TempDIR verification
if (!(Test-Path $TempDIR)) {$ErrorCount ++ ; Write-Host -ForegroundColor Red $TempDIR could not be created.}

# Test access to required files
if (!(Test-Path $DellOpenmanageInstallPath)) {$ErrorCount ++ ; Write-Host -ForegroundColor Red $DellOpenmanageInstallPath could not be accessed.}


# Verification evaluation
if ($ErrorCount -ne 0) { Write-Host -ForegroundColor Red $ErrorCount errors occurred during verification, Exiting... ; Pause ; throw }


# -- Script actions start here --

# Extract Openmanage to Temp folder
$DellOpenManageTempPath = $TempDIR + "DellOpenmanage\"
Add-Type -AssemblyName System.IO.Compression.FileSystem
try { [System.IO.Compression.ZipFile]::ExtractToDirectory($DellOpenmanageInstallPath, $DellOpenManageTempPath) }
catch {
    if ($_.Exception.Message -match "already exists") { Write-Host -ForegroundColor DarkYellow $_.Exception.Message }
    if ($_.Exception.Message -notmatch "already exists") { Write-Output $_.Exception.ErrorRecord ; break }
}

$DellOpenManageMetadataZipFileName = (Get-ChildItem $DellOpenManageTempPath "*metadata.zip" -File).Name

    # Copy to and install on each Dell ESXiHost
Foreach ($ESXiHost in $ESXiHosts) {

    # Set target datastore
    switch ($ESXiHost.LocalStorage) {
            No {$ESXiHostDatastore = Get-Datastore -RelatedObject $ESXiHost.Name | Where-Object -Property "Name" -Match -Value $ScratchDatastore}
            Yes {$ESXiHostDatastore = Get-Datastore -RelatedObject $ESXiHost.Name | Where-Object -Property "Name" -Like -Value "*datastore1*"}
    }
    if ((Get-VMHost $ESXiHost.Name).Manufacturer -like "*Dell*" -or $ESXiHost.LocalStorage -match "No") {
        if (Test-Path ESXiDatastore:/) {Remove-PSDrive ESXiDatastore}
        New-PSDrive -Location $ESXiHostDatastore -Name ESXiDatastore -PSProvider VimDatastore -Root “”

        # Check if Dell hardware, and install OpenManage if it is
        if ((Get-VMHost $ESXiHost.Name).Manufacturer -like "*Dell*") {
            if (!(Test-Path "ESXiDatastore:/Pulsant/DellOpenmanage")) { md ESXiDatastore:/Pulsant/DellOpenmanage }
            foreach ($DellOpenManageFile in (Get-ChildItem $DellOpenManageTempPath)) {
                $DellOpenManageESXiDatastoreFile = "ESXiDatastore:/Pulsant/DellOpenmanage/" + $DellOpenManageFile.Name
                if (!(Test-Path $DellOpenManageESXiDatastoreFile)) { Copy-DatastoreItem $DellOpenManageFile.FullName ESXiDatastore:/Pulsant/DellOpenmanage/ }
            }
            $DellOpenmanageMetadataZipESXiPath = "/vmfs/volumes/" + "$ESXiHostDatastore" + "/Pulsant/DellOpenmanage/" + $DellOpenManageMetadataZipFileName
            $esxcli = Get-EsxCli -VMHost $ESXiHost.Name
            #$esxcli.software.vib.install($null,$true,$false,$true,$true,$false,$null,$vibname,$viblocation)

            # Check if already in maintenence mode, set if not
            Enter-MaintenenceMode ($ESXiHost.Name)
            # Install Openmanage
            Install-VMHostPatch -VMHost $ESXiHost.Name -HostPath $DellOpenmanageMetadataZipESXiPath
        }

        # Check if no local storage is set, adjust scratch location if it is
        if ($ESXiHost.LocalStorage -match "No") {
            $ESXiHostShortName = $ESXiHost.Name.Substring(0,($ESXiHost.Name.IndexOf(".")))
            $ESXiHostShortName = $ESXiHostShortName.ToLower()
            md ESXiDatastore:/scratch/$ESXiHostShortName
            # $ESXiHostDatastoreUuid = $ESXiHostDatastore.ExtensionData.Info.Vmfs.Uuid
            $ESXiHostDatastoreName = $ESXiHostDatastore.Name
            $ScratchLocation = "/vmfs/volumes/$ESXiHostDatastoreName/scratch/$ESXiHostShortName"
            Get-AdvancedSetting -Entity $ESXiHost.Name -Name 'ScratchConfig.ConfiguredScratchLocation' | Set-AdvancedSetting -Value $ScratchLocation -Confirm:$false
        }
        Remove-PSDrive ESXiDatastore
        Restart-VMHost -VMHost $ESXiHost.Name -Confirm:$false
        WaitFor-VMHostRebootStart
    }
}

# Patch hosts (NEW)
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.Patch -match "Yes") {
        WaitFor-VMHostRebootFinish
        Test-Compliance -Entity (Get-VMHost $ESXiHost.Name)
        $ESXiHostCompliance = Get-Compliance (Get-VMHost $ESXiHost.Name)
        $Loop = 0
        While ($ESXiHostCompliance.Status -match "NotCompliant" -and $Loop -le 3) {
            $Loop ++
            Enter-MaintenenceMode ($ESXiHost.Name)
            Update-Entity -Baseline (Get-PatchBaseline -Entity $ESXiHost.Name -Inherit -Recurse) -Entity (Get-VMHost $ESXiHost.Name) -Confirm:$False
            Test-Compliance -Entity (Get-VMHost $ESXiHost.Name)
            $ESXiHostCompliance = Get-Compliance (Get-VMHost $ESXiHost.Name)
        }
    }
}

# Exit Maintenance Mode (NEW)
Foreach ($ESXiHost in $ESXiHosts) {
    if ($ESXiHost.ExitMaintenanceMode -match "Yes") {
        WaitFor-VMHostRebootCompletion
        Set-VMHost $ESXiHost.Name -State Connected
    }
}

# -- Close connections --
Net use /delete \\shared.dedipower.com\Provisioning
Disconnect-VIServer $vCenterAddress -Confirm:$false
