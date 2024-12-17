
$org = "https://dev.azure.com/bcagroup"
$project = "BCA.VehicleReferenceData"

# Get all groups
$groups = az pipelines variable-group list --org $org --project $project --output json | ConvertFrom-Json

# Loops through all groups
foreach ($group in $groups) {

    $groupName = $group.name
    $groupId = $group.id

    Write-Output "$groupName"

    $newGroup = az pipelines variable-group create --name $groupName --variables "dummy=value" --authorize true --org "https://dev.azure.com/bcagroup" --project "PEEP" | ConvertFrom-Json
    $newGroupId = $newGroup.id

    $variables = az pipelines variable-group variable list --org $org --project $project --id $groupId --output Json | ConvertFrom-Json

    foreach ($variable in $variables.psobject.Members | where-object {$_.MemberType -ne "Method" }) {

        $variableName = $variable.Name
        $variableValue = $variable.Value.value
        $variableIsSecret = $variable.Value.isSecret

        If ($variableIsSecret) {

            Write-Output "$groupName, $variableName, SECRET_VALUE"

            $newvar = az pipelines variable-group variable create --group-id $newGroupId --name $variableName --org "https://dev.azure.com/bcagroup" --project "PEEP" --value "SECRET VALUE"

        } else {

            Write-Output "$groupName, $variableName, $variableValue"

            $newvar = az pipelines variable-group variable create --group-id $newGroupId --name $variableName --org "https://dev.azure.com/bcagroup" --project "PEEP" --value "$variableValue"

        }

    }

    $delvar = az pipelines variable-group variable delete --group-id $newGroupId --name "Dummy" --org "https://dev.azure.com/bcagroup" --project "PEEP" --yes

}




















