<#
.SYNOPSIS
Adds or updates a user in Azure DevOps using the Azure CLI.

.DESCRIPTION
Checks if a user exists in Azure DevOps. If not, adds them with the specified license type.
If the user already exists, updates their license if needed.

.PARAMETER Organization
The full Azure DevOps organization URL (e.g., https://dev.azure.com/myorg).

.PARAMETER UserEmail
Email address of the user to add or update.

.PARAMETER LicenseType
License type to assign (express, stakeholder, earlyAdopter, advanced).

.EXAMPLE
.\AddOrUpdate-AzDoUser.ps1 -Organization "https://dev.azure.com/bcagroup" -UserEmail "someone@example.com" -LicenseType "express"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https://dev\.azure\.com/[\w-]+$')]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[\w\.-]+@[\w\.-]+\.\w+$')]
    [string]$UserEmail,

    [Parameter(Mandatory = $true)]
    [ValidateSet("express", "stakeholder", "earlyAdopter", "advanced")]
    [string]$LicenseType
)

# Function to check if user exists using az CLI
function Test-AzDoUserExists {
    param (
        [string]$UserEmail,
        [string]$Org
    )

    $result = az devops user show --user $UserEmail --org $Org --only-show-errors 2>&1

    if ($result -match "Could not resolve identity") {
        return $false
    } elseif ($result -match "Error") {
        Write-Error "❌ Error checking user: $result"
        return $null
    } else {
        return $true
    }
}

# Check if user exists
$userExists = Test-AzDoUserExists -UserEmail $UserEmail -Org $Organization

if ($userExists -eq $true) {
    Write-Host "🔄 User exists. Updating license..." -ForegroundColor Yellow
    az devops user update `
        --user $UserEmail `
        --license-type $LicenseType `
        --org $Organization `
        --detect false `
        --only-show-errors
    Write-Host "✅ Updated license for $UserEmail to $LicenseType." -ForegroundColor Green
}
elseif ($userExists -eq $false) {
    Write-Host "➕ User not found. Adding..." -ForegroundColor Cyan
    $addResult = az devops user add `
        --email-id $UserEmail `
        --license-type $LicenseType `
        --org $Organization `
        --send-email-invite false `
        --only-show-errors 2>&1

    if ($addResult -match "cannot be invited" -or $addResult -match "Error" -or $addResult -match "is not valid") {
        Write-Error "❌ Failed to add user. Message: $addResult"
    } else {
        Write-Host "✅ Added user $UserEmail with license $LicenseType." -ForegroundColor Green
    }
}

