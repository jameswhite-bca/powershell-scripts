# 🚀 PowerShell Scripts Repository

A comprehensive collection of PowerShell scripts organized by functionality and usage. This repository contains various automation scripts for different platforms and services.

## 📁 Directory Structure

### 🔐 Active Directory
- **Export Users.ps1** - Exports user information from Active Directory to a CSV file.

### 🛡️ ASAv
- **Deploy NAT Rules.PS1** - Deploys NAT rules to Cisco ASAv firewall.
- **Install ASAv.ps1** - Automated installation script for Cisco ASAv.
- **NAT_Builder_V2.8/** - Complete NAT rule management solution with documentation.

### 🔄 Azure DevOps
- **Get-AgentPoolInfo.ps1** - Retrieves detailed information about Azure DevOps agent pools.
- **Get-AzureDevOpsProjectUsers.ps1** - Exports all users from a specified Azure DevOps project to CSV.
- **Remove-AgentQueue.ps1** - Removes agent pool queues from Azure DevOps projects.
- **AddOrUpdate-AzDoUser.ps1** - Adds or updates users in Azure DevOps with specified licenses.

### ☁️ Azure
- **Migrate-AzKeyVaultSecrets.ps1** - Migrates secrets from one Azure Key Vault to another.

### 💾 Backup/Asigra
- Contains scripts for managing Asigra backup solutions.

### 🔑 Entra ID
- **Create-FederatedCredential.ps1** - Creates federated credentials for Azure AD applications.

### 📦 Install Software
- **Install-Agents.ps1** - Automated installation of various agents.
- **install-software.ps1** - Software package installation automation.
- **packages.config** - Configuration file for software packages.

### 🏢 M365
- **EnableMFA.ps1** - Enables Multi-Factor Authentication for users.
- **Get-MFAStatus.ps1** - Retrieves MFA status for users.
- **GetMFAStatusReport.ps1** - Generates comprehensive MFA status reports.
- **MFAstatus.ps1** - MFA status management tool.
- **MFAstatus2.ps1** - Enhanced MFA status management.
- **O365UserLicenseReport.ps1** - Generates Office 365 user license reports.

### 🛠️ MISC
- **CheckServersDNS.ps1** - DNS configuration verification tool.
- **Resource-Allocator.ps1** - Resource allocation management.
- **Send-MailInfosec.ps1** - Automated infosec email notifications.
- **Send-MailUltima.ps1** - New VM notification system.

### 💻 OS
- Operating system management and configuration scripts.

### 📝 Script Templates
- Template scripts for various automation tasks.

### 🖥️ vCenter
- **New-VCSA.ps1** - vCenter Server Appliance deployment automation.

### ☁️ vCloud
- **EdgeGateway Service V2 Firewall Additions v2.ps1** - EdgeGateway firewall rule management.

### 💽 Veeam
- **New-PECVeeamBackupRepo.ps1** - Veeam backup repository configuration.

### 🔄 Zerto
- Zerto disaster recovery management scripts.

## 🚀 Usage

Each script is designed for specific automation tasks. Detailed usage instructions are available in the comments of each script.

### 🔑 Prerequisites
- PowerShell 7.0 or later
- Required modules (specified in each script)
- Appropriate permissions for the target systems

### 📋 Example Usage

```powershell
# Azure Key Vault Migration
.\Azure\Migrate-AzKeyVaultSecrets.ps1 -SourceVaultName "source-kv" -TargetVaultName "target-kv" -AzureSubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Azure DevOps User Management
.\AzureDevOps\AddOrUpdate-AzDoUser.ps1 -Organization "your-org" -UserEmail "user@example.com" -AccessLevel "basic" -PAT "your-pat"

# MFA Management
.\M365\EnableMFA.ps1 -UserPrincipalName "user@domain.com"
```

## 🔒 Security Notes

- Always store sensitive information (like PAT tokens) securely
- Use appropriate permission levels for each script
- Review scripts before execution in production environments

## 📄 License

This repository is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For support, please open an issue in the repository.

---

Made with ❤️ by the PowerShell Automation Team
