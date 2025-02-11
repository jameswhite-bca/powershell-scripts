<#
.SYNOPSIS
    Retrieves all users from a given Azure DevOps project and exports their email addresses to a CSV file.

.DESCRIPTION
    This script retrieves all users from a specified Azure DevOps project using the Azure DevOps REST API.
    It fetches the project ID, retrieves the storage key, and then uses the scope descriptor to get the list of users.
    The user details are then exported to a CSV file.

.PARAMETER Organisation
    The name of the Azure DevOps organisation.

.PARAMETER Project
    The name of the Azure DevOps project.

.PARAMETER OutputCsv
    The path to the output CSV file.

.PARAMETER Pat
    The Azure DevOps Personal Access Token (PAT) for authentication.

.EXAMPLE
    .\Get-AzureDevOpsProjectUsers.ps1 -Organisation "bcagroup" -Project "ESP" -OutputCsv "c:\temp\ESPAzureDevOpsUsers.csv" -Pat "your-pat-here"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Organisation,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$OutputCsv,

    [Parameter(Mandatory = $true)]
    [string]$Pat
)

# Validate input parameters
if (-not $Organisation -or -not $Project -or -not $Pat) {
    Write-Host "Error: Missing required parameters." -ForegroundColor Red
    exit
}

# Encode PAT for authentication
$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
$Headers = @{
    Authorization = "Basic $Base64AuthInfo"
    "Content-Type" = "application/json"
}

# Step 1: Get the Project ID
$ProjectUrl = "https://dev.azure.com/$Organisation/_apis/projects?api-version=6.0"
$ProjectsResponse = Invoke-RestMethod -Uri $ProjectUrl -Headers $Headers -Method Get

$ProjectDetails = $ProjectsResponse.value | Where-Object { $_.name -eq $Project }

if (-not $ProjectDetails) {
    Write-Host "Error: Project '$Project' not found in Azure DevOps organisation '$Organisation'." -ForegroundColor Red
    exit
}

$ProjectId = $ProjectDetails.id
Write-Host "Found Project ID: $ProjectId for project '$Project'" -ForegroundColor Cyan

# Step 2: Get the Storage Key for the Project
$StorageKeyUrl = "https://vssps.dev.azure.com/$Organisation/_apis/graph/descriptors/$ProjectId" + "?api-version=5.0-preview.1"
$StorageKeyResponse = Invoke-RestMethod -Uri $StorageKeyUrl -Headers $Headers -Method Get

if (-not $StorageKeyResponse) {
    Write-Host "Error: Failed to retrieve storage key for project '$Project'." -ForegroundColor Red
    exit
}

$StorageKey = $StorageKeyResponse.value
Write-Host "Found Storage Key: $StorageKey for project '$Project'" -ForegroundColor Cyan

# Step 3: Get Users in the Project using Scope Descriptor
$DescriptorUrl = "https://vssps.dev.azure.com/$Organisation/_apis/graph/users?scopeDescriptor=$StorageKey&api-version=6.0-preview.1"
$UsersResponse = Invoke-RestMethod -Uri $DescriptorUrl -Headers $Headers -Method Get

# Extract user details
$UserList = @()
foreach ($User in $UsersResponse.value) {
    if ($User.mailAddress -match "@") {
        $UserObj = [PSCustomObject]@{
            DisplayName = $User.displayName
            Email       = $User.mailAddress
        }
        $UserList += $UserObj
    }
}

# Export to CSV
if ($UserList.Count -gt 0) {
    $UserList | Export-Csv -Path $OutputCsv -NoTypeInformation
    Write-Host "User email list exported successfully to: $OutputCsv" -ForegroundColor Green
} else {
    Write-Host "No valid user emails found to export." -ForegroundColor Red
}
