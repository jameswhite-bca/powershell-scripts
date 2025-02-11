# Define parameters
param (
    [string]$organisation,  # Azure DevOps organisation name
    [string]$agentPoolId,   # ID of the agent pool
    [string]$outputCsv,     # Output file for the CSV
    [string]$personalAccessToken # Personal Access Token (to be provided at runtime)
)

# Encode PAT for HTTP header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$personalAccessToken"))
$headers = @{ Authorization = "Basic $base64AuthInfo" }

# Define the API endpoint for the agent pool jobs (org-level)
$apiUrl = "https://dev.azure.com/$organisation/_apis/distributedtask/pools/$agentPoolId/jobrequests?api-version=6.0"
#https://dev.azure.com/bcagroup/_apis/distributedtask/pools/161/jobrequests?api-version=6.0
# Initialise an empty array to store jobs
$jobs = @()

# Pagination variables
$continuationToken = $null

do {
    # Add continuation token to the API request if present
    $url = $apiUrl
    if ($null -ne $continuationToken) {
        $url = "$apiUrl&continuationToken=$continuationToken"
    }

    # Make the API request
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

    # Check if the response has jobs
    if ($response -and $response.value) {
        # Add jobs to the array
        $jobs += $response.value
    }

    # Check for a continuation token to determine if there are more pages
    $continuationToken = if ($response -and $response.Headers -and $response.Headers.ContainsKey("x-ms-continuationtoken")) {
        $response.Headers["x-ms-continuationtoken"]
    } else {
        $null
    }
    $hasMorePages = $null -ne $continuationToken
} while ($hasMorePages)

# Extract additional details: pipeline name and project
$jobsExport = $jobs | ForEach-Object {
    [PSCustomObject]@{
        queueTime = $_.queueTime
        finishTime = $_.finishTime
        pipelineName = $_.definition.name
        project = $_.definition.project.name
    }
}

# Export to CSV
$jobsExport | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Output "Export complete. Jobs saved to $outputCsv."
