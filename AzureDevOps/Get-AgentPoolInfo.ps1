# Define parameters
param (
    [string]$organisation,  # Azure DevOps organisation name
    [string]$agentPoolId,   # ID of the agent pool
    [string]$outputCsv,     # Output file for the CSV
    [string]$personalAccessToken # Personal Access Token (to be provided at runtime)
)

# Calculate the date 30 days ago
$startDate = (Get-Date).AddDays(-30).ToString("o")

# Encode PAT for HTTP header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$personalAccessToken"))

# Initialise an empty array to store jobs
$jobs = @()

# Define the API endpoint for the agent pool jobs (org-level)
$apiUrl = "https://dev.azure.com/$organisation/_apis/distributedtask/pools/$agentPoolId/jobrequests?api-version=7.0-preview.1"

# Pagination variables
$hasMorePages = $true
$continuationToken = $null

while ($hasMorePages) {
    # Set up headers with the PAT
    $headers = @{ Authorization = "Basic $base64AuthInfo" }

    # Add continuation token to the API request if present
    $url = $apiUrl
    if ($null -ne $continuationToken) {
        $url = "$apiUrl&continuationToken=$continuationToken"
    }

    # Make the API request
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

    # Check if the response has jobs
    if ($response -and $response.value) {
        # Filter jobs within the past 30 days and add them to the array
        $jobs += $response.value | Where-Object { $_.queueTime -ge $startDate }
    }

    # Check for a continuation token to determine if there are more pages
    $continuationToken = if ($response -and $response.Headers -and $response.Headers.ContainsKey("x-ms-continuationtoken")) {
        $response.Headers["x-ms-continuationtoken"]
    } else {
        $null
    }
    $hasMorePages = $null -ne $continuationToken
}

# Extract additional details: pipeline name and project
$jobsExport = $jobs | ForEach-Object {
    [PSCustomObject]@{
        queueTime = $_.queueTime
        finishTime = $_.finishTime
        requestId = $_.requestId
        owner = $_.owner
        scope = $_.scope
        planType = $_.planType
        pipelineName = $_.definition.name   # Pipeline name
        project = $_.project.name          # Project name
    }
}

# Export the job data to CSV
$jobsExport | Select-Object queueTime, finishTime, requestId, owner, scope, planType, pipelineName, project | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "Export complete. Jobs saved to $outputCsv."
