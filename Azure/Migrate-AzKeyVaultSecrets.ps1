<#
.SYNOPSIS
    Migrates secrets from one Azure Key Vault to another.

.DESCRIPTION
    This script retrieves all secrets from a source Azure Key Vault and migrates them to a target Azure Key Vault.
    It ensures that secret values are securely transferred without exposing them in plain text.

.PARAMETER SourceVaultName
    The name of the source Azure Key Vault from which secrets will be retrieved.

.PARAMETER TargetVaultName
    The name of the target Azure Key Vault to which secrets will be migrated.

.PARAMETER AzureSubscriptionId
    The Azure subscription ID where the Key Vaults are located.

.EXAMPLE
    .\Migrate-AzKeyVaultSecrets.ps1 -SourceVaultName "source-kv" -TargetVaultName "target-kv" -AzureSubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.NOTES
    Ensure that the user or service principal running this script has the "Key Vault Secrets Officer" role assigned on both the source and target Key Vaults.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$SourceVaultName,

    [Parameter(Mandatory = $true)]
    [string]$TargetVaultName,

    [Parameter(Mandatory = $true)]
    [string]$AzureSubscriptionId
)

# Login to Azure (if not already logged in)
if (-not (Get-AzContext)) {
    Write-Host "Logging in to Azure..." -ForegroundColor Cyan
    Connect-AzAccount
}

# Set the Azure subscription
Write-Host "Setting Azure subscription to $AzureSubscriptionId..." -ForegroundColor Cyan
Set-AzContext -SubscriptionId $AzureSubscriptionId

# List and retrieve secrets from the source Key Vault
try {
    Write-Host "Retrieving secrets from source Key Vault: $SourceVaultName..." -ForegroundColor Cyan
    $secrets = Get-AzKeyVaultSecret -VaultName $SourceVaultName -ErrorAction Stop

    # Migrate secrets to the target Key Vault
    foreach ($secret in $secrets) {
        Write-Host "Migrating secret: $($secret.Name)..." -ForegroundColor Yellow

        # Retrieve the secret value as a SecureString
        $secretValue = (Get-AzKeyVaultSecret -VaultName $SourceVaultName -Name $secret.Name -ErrorAction Stop).SecretValue

        # Set the secret in the target Key Vault
        Set-AzKeyVaultSecret -VaultName $TargetVaultName -Name $secret.Name -SecretValue $secretValue -ErrorAction Stop
    }

    # Success message
    Write-Host "✅ Secrets migrated successfully from $SourceVaultName to $TargetVaultName." -ForegroundColor Green
} catch {
    # Failure message
    Write-Host "❌ Failed to migrate secrets from $SourceVaultName to $TargetVaultName. Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
