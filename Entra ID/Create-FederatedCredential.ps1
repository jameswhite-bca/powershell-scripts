<#
.SYNOPSIS
Creates a federated credential for an Azure AD application with embedded JSON structure.

.DESCRIPTION
This script constructs a federated credential JSON inline and submits it to Azure AD using the Azure CLI.
You only need to provide the App ID, credential name, and subject.

.PARAMETER AppId
The Azure AD Application (client) ID.

.PARAMETER Name
The name of the federated credential (should be a unique GUID or readable string. recommendation is to use the ID of the Azure DevOps Service Connection).

.PARAMETER Subject
The subject identifier in the federated credential (typically a service connection string from Azure DevOps).

.EXAMPLE
.\Create-FederatedCredential.ps1 -AppId "c72a78b2-572f-4c86-9613-6b0736e9b868" `
    -Name "931ea003-fee2-4bfb-81e5-cb45439f93e9" `
    -Subject "sc://organisation/project/JamesTest - UAT"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Subject
)

# Define constants
$Issuer = "https://vstoken.dev.azure.com/d4a0bc48-f4ba-4477-a0d3-94a9638b93e8"
$Audiences = @("api://AzureADTokenExchange")

# Create the JSON content dynamically
$credential = @{
    name     = $Name
    issuer   = $Issuer
    subject  = $Subject
    audiences = $Audiences
}

# Convert the hashtable to JSON
$credentialJson = $credential | ConvertTo-Json -Depth 3

# Create a temporary file to store the JSON
$tempFile = New-TemporaryFile
$credentialJson | Set-Content -Path $tempFile -Encoding utf8

# Run the az CLI command
try {
    Write-Host "Creating federated credential for App ID: $AppId"
    az ad app federated-credential create --id $AppId --parameters $tempFile
    Write-Host "Federated credential created successfully."
} catch {
    Write-Error "Failed to create federated credential: $_"
} finally {
    # Clean up
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}
