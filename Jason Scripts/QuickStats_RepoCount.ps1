$org = "https://dev.azure.com/bcagroup"
$projectFetchCount = 500

$projects = az devops project list --org $org --query "value[]" --top $projectFetchCount --output json | convertfrom-json
$projectsCount = ($projects | Measure-Object).Count

foreach ($project in $projects) {

    $projectCount ++
    
    # Get string values from project object
    $projectname = $project.name

    $repos = az repos list --org $org --project "$projectname" --only-show-errors | ConvertFrom-Json
    $projectreposCount = ($repos | Measure-Object).Count
    $TotalRepos = $TotalRepos  + $projectreposCount

    $releases = az pipelines release definition list --org $org --project "$projectname" --top 500 | ConvertFrom-Json
    $releasesCount = ($releases | Measure-Object).Count
    $TotalReleases = $TotalReleases + $releasesCount

    $pipelines = az pipelines list --org $org --project "$projectname" --query-order NameAsc --top 500 --only-show-errors | ConvertFrom-Json
    $projectpipelinesCount = ($pipelines | Measure-Object).Count
    $TotalPipelines = $TotalPipelines + $projectpipelinesCount

    write-output "Processing Project : $projectname ($projectCount/$projectsCount) - TotalRepos = $TotalRepos - TotalReleases = $TotalReleases - TotalPipelines = $TotalPipelines"

}


$users = az devops user list --org $org | ConvertFrom-Json
$TotalUsers = $users.totalcount

$allPipelines = $TotalPipelines + $TotalReleases

write-output "Projects: $projectsCount"
write-output "Repos: $TotalRepos"
write-output "Release Pipelines : $TotalReleases"
write-output "Yaml Pipelines : $TotalPipelines"
write-output "Total Pipelines : " $allPipelines
write-output "Users : $TotalUsers"

