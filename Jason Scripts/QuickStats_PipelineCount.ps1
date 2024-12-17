$org = "https://dev.azure.com/bcagroup"
$projectFetchCount = 250
$pipelineFetchDays = -1
$queryDate = ((Get-Date).AddDays($pipelineFetchDays)).tostring("yyyy-MM-dd")
$queryDate

$projectCount = 0
$projectpipelineCount = 0
$TotalRuns = 0

$projects = az devops project list --org $org --query "value[]" --top $projectFetchCount --output json | convertfrom-json
$projectsCount = ($projects | Measure-Object).Count

foreach ($project in $projects) {

    $projectCount ++
    
    # Get string values from project object
    $projectname = $project.name

    $pipelines = az pipelines list --org $org --project "$projectname" --query-order NameAsc --top 500 --only-show-errors | ConvertFrom-Json
    $projectpipelinesCount = ($pipelines | Measure-Object).Count
    $projectpipelineCount = 0

    foreach ($pipeline in $pipelines) {

        $pipelineCount ++
        $projectpipelineCount ++

        # Get string values from pipeline object
        $pipelineid = $pipeline.id #2

        # Get all runs in pipelines
        $pipelineruns = az pipelines runs list --org $org --project $projectname --query-order QueueTimeDesc --query "[?queueTime > '$queryDate']" --pipeline-ids $pipelineid --top 5000 --only-show-errors | ConvertFrom-Json 
        $projectpipelinerunsCount = ($pipelineruns | Measure-Object).Count
        $TotalRuns = $TotalRuns + $projectpipelinerunsCount
        
        write-output "Processing Project : $projectname ($projectCount/$projectsCount) - Pipeline : ($projectpipelineCount/$projectpipelinesCount) - Runs : ($TotalRuns)"

    }

}


