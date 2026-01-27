# Azure Container Apps Cost Allocation - User Guide

## What This Tool Does

When multiple Container Apps share Dedicated Workload Profiles (D4, D8, E4, etc.), Azure bills at the **profile level**, not per app. This tool analyzes actual resource usage to fairly allocate costs across applications.

**Quick Links:**
- 📘 [README.md](README.md) - Overview and basic usage
- ⚡ [QUICKSTART.md](QUICKSTART.md) - 5-minute setup guide
- 📊 [EXAMPLE.md](EXAMPLE.md) - Detailed walkthrough

---

## Prerequisites

### Software Requirements
- **PowerShell 5.1+** (built-in on Windows) or **PowerShell 7+**
- **Azure CLI** - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)

### Azure Permissions
- **Reader** role on Container Apps resources
- **Monitoring Reader** role for Azure Monitor metrics

### Important: Managed Device Considerations
If running on a company-managed device with Conditional Access policies:
- Azure CLI authentication typically works (browser-based)
- Az PowerShell may fail with "device must be managed" errors
- This script automatically uses Azure CLI-first authentication

---

## Installation

```powershell
# Clone the repository
git clone https://github.com/jkalis-MS/ACA-Dedicated-Profile-Cost-Allocation.git
cd ACA-Dedicated-Profile-Cost-Allocation

# Login to Azure
az login

# Run the script
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "your-resource-group" `
    -EnvironmentName "your-container-app-env"
```

---

## Understanding Output

### Console Output
```
Workload Profile: production-d8 (D8, Cost Weight: 2.0)

  api-service
    Profile Allocation: 65.43%        ← % of THIS profile's cost
    Environment-Wide Cost: 45.62%     ← % of TOTAL environment cost
    - CPU Usage: 70.25% (2.1 cores avg)
    - Memory Usage: 58.32% (9.3 GiB avg)
    - Replica Time: 60.00% (144 replica-hours)
```

### Key Metrics

| Metric | Meaning |
|--------|---------|
| **Profile Allocation** | App's % of its workload profile's cost (sums to 100% per profile) |
| **Environment-Wide Cost** | App's % of total environment cost across all profiles |

### CSV Export
File: `ACA-CostBreakdown-{env}-{timestamp}.csv`

Contains detailed metrics including CPU, memory, replica counts, and both profile and environment-wide percentages.

---

## Calculating Actual Dollar Amounts

The script provides **percentages only**. To get actual costs:

### Step 1: Get Total Costs from Azure Portal
1. Go to **Cost Management + Billing** → **Cost Analysis**
2. Filter by your Resource Group and date range
3. Note the total cost for the environment

### Step 2: Multiply Percentages by Total Cost

**Example:**
- Total environment cost (7 days): **$1,400**
- `api-service` environment-wide allocation: **45.62%**
- **api-service cost: $1,400 × 0.4562 = $638.68**

### Step 3: Add Costs to CSV (Optional)

```powershell
$results = Import-Csv ".\ACA-CostBreakdown-*.csv"
$totalCost = 1400  # Your actual cost from Azure

$results | ForEach-Object {
    $actualCost = [Math]::Round(($_.EnvironmentCostPercent / 100) * $totalCost, 2)
    $_ | Add-Member -NotePropertyName "ActualCost" -NotePropertyValue $actualCost
}

$results | Export-Csv ".\CostBreakdown-WithDollars.csv" -NoTypeInformation
```

---

## Common Scenarios

### Analyze Last 7 Days
```powershell
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId $subId `
    -ResourceGroupName $rg `
    -EnvironmentName $env `
    -StartDate (Get-Date).AddDays(-7)
```

### Custom Allocation Weights
```powershell
# CPU-heavy workloads
-CpuWeight 0.7 -MemoryWeight 0.2 -ReplicaTimeWeight 0.1

# Memory-heavy workloads
-CpuWeight 0.4 -MemoryWeight 0.5 -ReplicaTimeWeight 0.1
```

### Multiple Environments
```powershell
$environments = @("prod-env", "staging-env", "dev-env")
foreach ($env in $environments) {
    .\Get-ACAEnvironmentCostBreakdown.ps1 `
        -SubscriptionId $subId `
        -ResourceGroupName $rg `
        -EnvironmentName $env `
        -OutputPath "./reports/$env"
}
```

---

## Troubleshooting

### "Not logged in to Azure"
```powershell
az login
# If that fails on managed devices:
Connect-AzAccount -UseDeviceAuthentication
```

### "Your admin requires the device to be managed"
**Solution:** Use Azure CLI authentication (built into script):
```powershell
az login  # This typically works even when Connect-AzAccount fails
```

### "No dedicated workload profiles found"
Your environment uses only **Consumption profiles**. Consumption profiles are billed per-replica, so cost allocation is unnecessary. This tool is for **Dedicated profiles** only.

To analyze Consumption profiles anyway (not recommended):
```powershell
-OnlyDedicated:$false
```

### "Unused Dedicated Workload Profiles" Warning
You have dedicated profiles provisioned with **no apps running**. You're still being charged.

**Solution:** Delete unused profiles:
```powershell
az containerapp env workload-profile delete `
    --name <profile-name> `
    --resource-group <rg> `
    --environment-name <env>
```

### "No metrics returned"
**Causes:**
- Apps weren't running during analysis period
- Metrics not yet available (wait 5-10 minutes after deployment)
- Missing Monitoring Reader permission

**Solutions:**
- Verify apps were active: `az containerapp list --resource-group <rg> --output table`
- Check permissions: Request **Monitoring Reader** role from admin
- Try different time range: `-StartDate (Get-Date).AddHours(-6)`

### "Unknown workload profile type"
The profile uses an unsupported SKU type.

**Check configuration:**
```powershell
az containerapp env show --name <env> --resource-group <rg> --query "properties.workloadProfiles"
```

**Supported SKUs:** D4, D8, D16, D32, E4, E8, E16, E32

### "cryptography backend.py" Warning
This harmless warning is from Azure CLI's Python libraries (not the script):
```
UserWarning: You are using cryptography on a 32-bit Python on a 64-bit Windows...
```

**Impact:** None - script runs correctly, just slightly slower

**Fix (optional):** Install 64-bit Azure CLI from https://aka.ms/installazurecliwindows

---

## Best Practices

### Analysis Frequency
- **Daily**: Active cost monitoring, rapid feedback
- **Weekly**: Standard operational reviews
- **Monthly**: Trend analysis, budgeting, chargebacks

### Time Range Selection
- **1-3 days**: Quick checks, troubleshooting
- **7-30 days**: Accurate averages, smooths variability
- **Avoid <6 hours**: Metrics may be incomplete

### Validation
Always verify the validation section shows ✓:
```
✓ Profile 'production-d8' allocation: 100%
✓ Environment-wide total allocation: 100%
```

If you see ⚠ warnings, percentages don't sum to 100% - review data quality.

---

## Advanced: Automation

### Schedule with Azure Automation
```powershell
# 1. Upload script to Automation Account
# 2. Configure Managed Identity with Reader + Monitoring Reader
# 3. Create runbook schedule (daily/weekly)
# 4. Store CSV outputs in Azure Storage
```

### Export to Power BI
```powershell
# Generate CSV with timestamp
$date = Get-Date -Format "yyyy-MM-dd"
.\Get-ACAEnvironmentCostBreakdown.ps1 ... -OutputPath ".\reports\$date"

# Import to Power BI from reports folder
# Create trending visualizations
```

---

## Limitations

| Limitation | Impact |
|------------|--------|
| Percentages only | Multiply by actual costs from Cost Management |
| Dedicated profiles only | Consumption already billed per-replica |
| 93-day metric retention | Can't analyze older periods |
| No GPU profiles | GPU pricing different (future enhancement) |

---

## Support

**Issues or questions:**
1. Check [README.md](README.md) and [QUICKSTART.md](QUICKSTART.md)
2. Review troubleshooting section above
3. Open issue on GitHub repository

**Version:** 1.0 (January 2026)
