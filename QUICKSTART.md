# Quick Start Guide

## Prerequisites Check

Run this to verify your environment is ready:

```powershell
# Check PowerShell version (need 5.1+)
$PSVersionTable.PSVersion

# Check Azure CLI
az --version

# Check Az PowerShell module
Get-Module -ListAvailable Az.Accounts

# If Az.Accounts not installed:
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
```

## First Run

```powershell
# 1. Login to Azure
az login

# 2. Run the script
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "YOUR-SUBSCRIPTION-ID" `
    -EnvironmentName "YOUR-ENVIRONMENT-NAME"
```

## What You Need

To run the script, provide these values:

1. **Subscription ID** (required): Find in Azure Portal → Subscriptions
2. **Environment Name** (required): Your Container Apps Environment name

> **Note:** The script automatically discovers apps across all resource groups targeting the environment.

## Quick Test

```powershell
# Basic run
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -EnvironmentName "my-aca-env"

# With custom weights
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -EnvironmentName "my-aca-env" `
    -CpuWeight 0.85 -MemoryWeight 0.15
```

## Expected Output

The script will:
1. ✓ Connect to Azure
2. ✓ Find your Container Apps Environment
3. ✓ List workload profiles (must have Dedicated profiles)
4. ✓ List container apps using those profiles (all resource groups)
5. ✓ Collect reserved capacity (CPU × replicas, Memory × replicas)
6. ✓ Calculate cost allocation percentages
7. ✓ Export CSV report
8. ✓ Display summary on screen

## Troubleshooting

**"Not logged in to Azure"**
```powershell
az login
```

**"Environment not found"**
- Check the environment name is correct
- Verify the subscription ID

**"No dedicated workload profiles found"**
- Your environment uses only Consumption profiles
- This tool is for Dedicated profiles only

**Apps showing 0% allocation**
- Check that minReplicas > 0 for your apps
- Apps with minReplicas=0 don't reserve capacity

## Next Steps

After successful run:
1. Review the CSV file in current directory
2. Get actual costs from Azure Portal → Cost Management
3. Multiply percentages by actual costs for per-app costs
4. Schedule regular runs (weekly/monthly recommended)
