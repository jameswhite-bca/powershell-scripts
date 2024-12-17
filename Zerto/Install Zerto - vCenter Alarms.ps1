#Author: Richard Hilton
#Version: 1.0
#Purpose: Set vCenter alarm actions for required Zerto alarms.

#Last Change by: Richard Hilton
#Status: Ready for second test
#Recommended Run Mode: Semi-automatic (Powershell ISE; Manual execution; entire script)
#Changes: Initial Creation
#Adjustments Required: None

# -- Script actions start here --

#Initialize PowerCLI
. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
. "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$False

#Connect to vCenter
Connect-VIServer localhost

# Add Alarms
        #com.zerto.event.CloudConnector
    $vCenterAlarmDefinition = "com.zerto.event.CloudConnector"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.HostPasswordChanged
    $vCenterAlarmDefinition = "com.zerto.event.HostPasswordChanged"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.LastTest
    $vCenterAlarmDefinition = "com.zerto.event.LastTest"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.License
    $vCenterAlarmDefinition = "com.zerto.event.License"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.MissingOrgVdcNetworkMapping
    $vCenterAlarmDefinition = "com.zerto.event.MissingOrgVdcNetworkMapping"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.PeerZvmCompatibility
    $vCenterAlarmDefinition = "com.zerto.event.PeerZvmCompatibility"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.ProtectionGroupError
    $vCenterAlarmDefinition = "com.zerto.event.ProtectionGroupError"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.ProtectionGroupMissingConfiguration
    $vCenterAlarmDefinition = "com.zerto.event.ProtectionGroupMissingConfiguration"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.ProtectionGroupPaused
    $vCenterAlarmDefinition = "com.zerto.event.ProtectionGroupPaused"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.RecoveryDataStoreFull
    $vCenterAlarmDefinition = "com.zerto.event.RecoveryDataStoreFull"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.RecoveryDataStoreLowFreeSpace
    $vCenterAlarmDefinition = "com.zerto.event.RecoveryDataStoreLowFreeSpace"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.RpoWarning
    $vCenterAlarmDefinition = "com.zerto.event.RpoWarning"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.VraIpChanged
    $vCenterAlarmDefinition = "com.zerto.event.VraIpChanged"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.VraPoweredOff
    $vCenterAlarmDefinition = "com.zerto.event.VraPoweredOff"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.ZvmToVraConnection
    $vCenterAlarmDefinition = "com.zerto.event.ZvmToVraConnection"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #com.zerto.event.ZvmToZvmConnection
    $vCenterAlarmDefinition = "com.zerto.event.ZvmToZvmConnection"
    $vCenterAlarmAction = New-AlarmAction $vCenterAlarmDefinition -Email -To "support@pulsant.com"
    $vCenterAlarmAction | New-AlarmActionTrigger -StartStatus Yellow -EndStatus Green

        #
    $vCenterAlarmDefinition = ""

        #Show full alarm info (debugging)
    #$vCenterAlarmDefinition = "Cannot Connect to Storage"
    #Get-AlarmDefinition $vCenterAlarmDefinition | fl
    #(Get-View -Id (Get-AlarmDefinition -Name $vCenterAlarmDefinition).Id).Info.Expression.Expression
    #(Get-View -Id (Get-AlarmDefinition -Name $vCenterAlarmDefinition).Id).Info.Expression.Expression.Metric
    #Get-AlarmDefinition $vCenterAlarmDefinition | Get-AlarmAction | fl
    #Get-AlarmDefinition $vCenterAlarmDefinition | Get-AlarmAction | Get-AlarmActionTrigger | fl
    #Get-AlarmDefinition $vCenterAlarmDefinition | Get-AlarmAction -ActionType SendEmail | Get-AlarmActionTrigger | fl
