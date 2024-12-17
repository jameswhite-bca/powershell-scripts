$org = "https://dev.azure.com/bcagroup"
$search_id = "5323fc91-923f-4833-839a-79e019fe5d67"

Remove-Item -Path c:\temp\sc.csv

$projects = az devops project list --org $org --state-filter all --top 500 --output Json | ConvertFrom-Json

$project_count = 0
$projects_count = $projects.value.Count

foreach ($project in $projects.value) {

    $project_count ++
    $project_name = $project.name

    $service_connections = az devops service-endpoint list --org $org --project $project_name --output Json | ConvertFrom-Json
    $service_connections_count = $service_connections.count

    foreach ($service_connection in $service_connections) {

        $service_connection_name = $service_connection.name
        $created_by = $service_connection.createdBy.displayName
        $spn_id = $service_connection.data.appObjectId
        $data = $service_connection.data
        $description = $service_connection.description
        $id = $service_connection.id
        $shared = $service_connection.isShared
        $operation_status = $service_connection.operationStatus
        $owner = $service_connection.owner
        $service_endpoint_project_references = $service_connection.serviceEndpointProjectReferences
        $type = $service_connection.type
        $url = $service_connection.url

        write-host "Project : $project_name ($project_count/$projects_count) - $service_connection_name"

        if ($service_connection_name -eq "Sonar Cloud") {

            if ($id -eq $search_id) {

                az devops service-endpoint delete --org $org --project $project_name --id $id --yes

            }

        } else {

            [PSCustomObject]@{
                project_name = $project_name
                service_connection_name = $service_connection_name
                created_by = $created_by
                spn_id = $spn_id
                data = $data
                description = $description
                id = $id
                shared = $shared
                operation_status = $operation_status
                owner = $owner
                service_endpoint_project_references = $service_endpoint_project_references
                type = $type
                url = $url
            } | Export-Csv -Path c:\temp\sc.csv -Append

        }

    }

}


