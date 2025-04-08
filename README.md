# PowerShell Scripts

This repository is a personal collection of PowerShell scripts organized into various directories based on their functionality and usage.

## Directory Structure

- **Active Directory/**
  - `Export Users.ps1`: Script to export users from Active Directory.

- **ASAv/**
  - `Deploy NAT Rules.PS1`: Script to deploy NAT rules.
  - `Install ASAv.ps1`: Script to install ASAv.
  - `NAT_Builder_V2.8/`: Directory containing NAT Builder version 2.8 scripts and documentation.

- **AzureDevOps/**
  - `Get-AgentPoolInfo.ps1`: Script to get information about Azure DevOps agent pools.
  - `Get-AzureDevOpsProjectUsers.ps1`: Script to retrieve all users from a specified Azure DevOps project and export their email addresses to a CSV file.
  - `Remove-AgentQueue.ps1`: Removes an agent pool queue from a specific Azure DevOps project.
  - `Get-AzureDevOpsProjectUsers.ps1`: Removes a specified agent pool queue (by name) from all projects in an Azure DevOps organization.

- **Backup/Asigra/**: Directory for Asigra backup scripts.

- **install-software/**
  - `Install-Agents.ps1`: Script to install agents.
  - `install-software.ps1`: Script to install various software packages.
  - `packages.config`: Configuration file listing software packages to be installed.

- **M365/**
  - `EnableMFA.ps1`: Script to enable Multi-Factor Authentication (MFA).
  - `Get-MFAStatus.ps1`: Script to get MFA status.
  - `GetMFAStatusReport.ps1`: Script to generate MFA status report.
  - `MFAstatus.ps1`: Script related to MFA status.
  - `MFAstatus2.ps1`: Another script related to MFA status.
  - `O365UserLicenseReport.ps1`: Script to generate Office 365 user license report.

- **MISC/**
  - `CheckServersDNS.ps1`: Script to check DNS settings on servers.
  - `Resource-Allocator.ps1`: Script for resource allocation.
  - `Send-MailInfosec.ps1`: Script to send infosec-related emails.
  - `Send-MailUltima.ps1`: Script to send emails related to new VMs.

- **OS/**: Directory for operating system-related scripts.

- **Script Templates/**: Directory containing script templates.

- **vCenter/**
  - `New-VCSA.ps1`: Script to create a new vCenter Server Appliance (VCSA).

- **vCloud/**: Directory for vCloud-related scripts.
  - `EdgeGateway Service V2 Firewall Additions v2.ps1`: Script for adding firewall rules to EdgeGateway Service V2.

- **Veeam**
  - `New-PECVeeamBackupRepo.ps1`: Script to configure a new Veeam Backup Repository.

- **Zerto/**: Directory for Zerto-related scripts.

## Usage

Each script is designed to perform specific tasks. Please refer to the comments and documentation within each script for detailed usage instructions.

## License

This repository is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.
