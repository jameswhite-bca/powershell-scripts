<#
.SYNOPSIS
    Removes an agent pool queue from a specific Azure DevOps project.

.DESCRIPTION
    This script uses the Azure DevOps REST API to remove a queue (agent pool mapping)
    from a specified project. This effectively "removes" the agent pool from the project.

.EXAMPLE
    .\Remove-AgentQueue.ps1 -Organization "my-org" -Project "my-project" -QueueId 123 -PAT "your-pat"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [int]$QueueId,

    [Parameter(Mandatory = $true)]
    [string]$PAT
)

# Encode PAT for authentication
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    Accept        = "application/json"
}

# Construct the DELETE URL
$deleteUrl = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/queues/$QueueId" + "?api-version=7.1"

try {
    Write-Host "🔧 Deleting queue ID $QueueId from project '$Project'..."
    Invoke-RestMethod -Uri $deleteUrl -Headers $headers -Method Delete
    Write-Host "✅ Successfully removed agent queue from project '$Project'" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to remove agent pool: $_"
}
