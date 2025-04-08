<#
.SYNOPSIS
    Removes a specified agent pool queue (by name) from all projects in an Azure DevOps organization.

.DESCRIPTION
    This script loops through all projects in the specified organization and attempts to remove
    a matching agent queue (by name) from each project using the Azure DevOps REST API.

.EXAMPLE
    .\Remove-AgentQueueFromAllProjects.ps1 -Organization "my-org" -QueueName "linux-pool" -PAT "your-pat"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [string]$QueueName,

    [Parameter(Mandatory = $true)]
    [string]$PAT
)

# Base64-encoded PAT for auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    Accept        = "application/json"
}

# Get all projects
$projectsUrl = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"
Write-Host "📋 Fetching all projects..."
$projects = Invoke-RestMethod -Uri $projectsUrl -Headers $headers -Method Get

foreach ($project in $projects.value) {
    $projectName = $project.name
    Write-Host "🔍 Searching queues in '$projectName'..."

    # Get all agent queues for this project
    $queuesUrl = "https://dev.azure.com/$Organization/$projectName/_apis/distributedtask/queues?api-version=7.1"
    try {
        $queues = Invoke-RestMethod -Uri $queuesUrl -Headers $headers -Method Get
    } catch {
        Write-Warning "⚠ Failed to get queues for project '$projectName': $_"
        continue
    }

    # Find matching queue
    $targetQueue = $queues.value | Where-Object { $_.name -eq $QueueName }
    if ($targetQueue) {
        $queueId = $targetQueue.id
        Write-Host "🗑 Removing queue '$QueueName' (ID: $queueId) from '$projectName'..."

        $deleteUrl = "https://dev.azure.com/$Organization/$projectName/_apis/distributedtask/queues/$queueId" + "?api-version=7.1"
        try {
            Invoke-RestMethod -Uri $deleteUrl -Headers $headers -Method Delete
            Write-Host "✅ Removed from '$projectName'" -ForegroundColor Green
        } catch {
            Write-Warning "❌ Failed to remove from '$projectName': $_"
        }
    } else {
        Write-Host "ℹ No queue named '$QueueName' found in '$projectName'"
    }
}

Write-Host "🏁 All done."
