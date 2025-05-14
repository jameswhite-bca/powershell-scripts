param (
    [Parameter(Mandatory = $true)][string]$org,             # e.g. "myorg"
    [Parameter(Mandatory = $true)][string]$pat,             # Personal Access Token
    [Parameter(Mandatory = $true)][string]$project,         # Azure DevOps project name
    [Parameter(Mandatory = $true)][string]$repository,      # Repository name
    [Parameter(Mandatory = $true)][string]$sourceBranch,    # e.g. "refs/heads/develop"
    [Parameter(Mandatory = $true)][string]$targetBranch,    # e.g. "refs/heads/main"
    [Parameter(Mandatory = $true)][string]$reviewerId       # GUID of the reviewer
)

# Encode PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{ Authorization = "Basic $base64AuthInfo" }

# Create PR
$prBody = @{
    sourceRefName  = $sourceBranch
    targetRefName  = $targetBranch
    title          = "Merge $($sourceBranch -replace 'refs/heads/', '') to $(($targetBranch -replace 'refs/heads/', ''))"
    description    = "Automated PR from $sourceBranch to $targetBranch"
} | ConvertTo-Json -Depth 3

$prUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$repository/pullrequests?api-version=7.1"
$pr = Invoke-RestMethod -Uri $prUrl -Headers $headers -Method Post -Body $prBody -ContentType "application/json"

Write-Host "✅ Pull Request created: ID $($pr.pullRequestId)"

# Assign reviewer
$reviewerBody = @{
    reviewers = @(@{ id = $reviewerId; isRequired = $true })
} | ConvertTo-Json -Depth 2

$reviewerUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$repository/pullRequests/$($pr.pullRequestId)/reviewers/$($reviewerId)?api-version=7.1"
Invoke-RestMethod -Uri $reviewerUrl -Headers $headers -Method Put -Body $reviewerBody -ContentType "application/json"
Write-Host "👤 Reviewer assigned"

# Approve the PR on behalf of the reviewer
$approveBody = @{ vote = 10 } | ConvertTo-Json
$approveUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$repository/pullrequests/$($pr.pullRequestId)/reviewers/$($reviewerId)?api-version=7.1"
Invoke-RestMethod -Uri $approveUrl -Headers $headers -Method Put -Body $approveBody -ContentType "application/json"
Write-Host "👍 PR approved by reviewer"

# Enable auto-complete
$autoCompleteBody = @{
    autoCompleteSetBy = @{ id = $reviewerId }
    completionOptions = @{
        mergeStrategy = "noFastForward"
        deleteSourceBranch = $true
    }
} | ConvertTo-Json -Depth 3

$autoCompleteUrl = "https://dev.azure.com/$org/$project/_apis/git/repositories/$repository/pullrequests/$($pr.pullRequestId)?api-version=7.1"
Invoke-RestMethod -Uri $autoCompleteUrl -Headers $headers -Method Patch -Body $autoCompleteBody -ContentType "application/json"
Write-Host "🔁 Auto-complete enabled and PR ready to merge"
