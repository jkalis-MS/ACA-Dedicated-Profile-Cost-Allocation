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
Connect-AzAccount
az login

# 2. Run the script (replace with your values)
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "YOUR-SUBSCRIPTION-ID" `
    -ResourceGroupName "YOUR-RESOURCE-GROUP" `
    -EnvironmentName "YOUR-ENVIRONMENT-NAME"
```

## What You Need

To run the script, provide these three values:

1. **Subscription ID**: Find in Azure Portal → Subscriptions
2. **Resource Group**: The RG containing your Container App Environment
3. **Environment Name**: Your Container Apps Environment name

## Quick Test

```powershell
# Test with last 24 hours (default)
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -ResourceGroupName "my-rg" `
    -EnvironmentName "my-aca-env"

# Test with last 7 days
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -ResourceGroupName "my-rg" `
    -EnvironmentName "my-aca-env" `
    -StartDate (Get-Date).AddDays(-7)
```

## Expected Output

The script will:
1. ✓ Connect to Azure
2. ✓ Find your Container Apps Environment
3. ✓ List workload profiles (must have Dedicated profiles)
4. ✓ List container apps using those profiles
5. ✓ Collect CPU/memory/replica metrics
6. ✓ Calculate cost allocation percentages
7. ✓ Export CSV report
8. ✓ Display summary on screen

## Troubleshooting

**"Not logged in to Azure"**
```powershell
Connect-AzAccount
az login
```

**"No dedicated workload profiles found"**
- Your environment uses only Consumption profiles
- This tool is for Dedicated profiles only

**"Failed to retrieve metrics"**
- Wait a few minutes after app deployment for metrics to appear
- Check that apps were actually running during the time period
- Verify you have Monitoring Reader role

## Next Steps

After successful run:
1. Review the CSV file in current directory
2. Get actual costs from Azure Portal → Cost Management
3. Multiply percentages by actual costs for per-app costs
4. Schedule regular runs (weekly/monthly recommended)
