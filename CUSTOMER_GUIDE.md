# Azure Container Apps Cost Allocation Tool - Customer Guide

## Overview

This PowerShell script analyzes Azure Container Apps running on **Dedicated Workload Profiles** and calculates the percentage of infrastructure costs attributable to each application based on actual resource consumption.

### Why You Need This Tool

When multiple Container Apps share Dedicated Workload Profiles (D4, D8, E4, etc.), Azure bills at the **profile instance level**, not per application. This makes it challenging to:
- Allocate costs to specific applications or teams
- Understand which apps drive infrastructure costs
- Make informed scaling and optimization decisions

This tool solves that problem by analyzing actual CPU, memory, and runtime metrics to fairly allocate costs.

## Key Features

✅ **Region-Agnostic Cost Weights**: Uses relative pricing based on SKU tiers (D4-D32, E4-E32)  
✅ **Multi-Profile Support**: Handles environments with multiple workload profiles  
✅ **Accurate Allocation**: Weighted formula (60% CPU, 30% memory, 10% replica-time)  
✅ **Transparent**: Pure PowerShell script - no compiled code, fully inspectable  
✅ **Easy to Use**: Single command execution with Azure CLI authentication  
✅ **CSV Export**: Detailed breakdown for analysis and reporting  

## How It Works

```
1. Connects to your Azure subscription (via Azure CLI)
2. Retrieves Container Apps Environment (az containerapp env show)
3. Extracts Workload Profiles with SKU types from environment properties
4. Lists all Container Apps using dedicated profiles
5. Collects metrics from Azure Monitor (CPU, memory, replicas)
6. Calculates allocation using weighted formula + SKU-based cost weights
7. Exports results to CSV and displays summary
```

### SKU Detection

The script reads the `workloadProfileType` property directly from the environment configuration. Azure populates this with the exact SKU (D4, D8, D16, D32, E4, E8, E16, E32), ensuring accurate cost weight application without relying on profile naming conventions.

### Cost Allocation Formula

**Per Profile:**
```
App % = (CPU% × 0.6) + (Memory% × 0.3) + (ReplicaTime% × 0.1)
```

**Environment-Wide (Multiple Profiles):**
```
Profile Cost Weight × App Profile % / Total Weighted Cost
```

#### Profile Cost Weights (Relative to D4 = 1.0)

Based on official Azure pricing, normalized to be region-agnostic:

| Profile | vCPU | RAM (GiB) | Cost Weight | Monthly Cost* |
|---------|------|-----------|-------------|---------------|
| **General Purpose D-Series** |
| D4  | 4  | 16  | 1.00 | ~$225 |
| D8  | 8  | 32  | 2.00 | ~$450 |
| D16 | 16 | 64  | 4.00 | ~$899 |
| D32 | 32 | 128 | 8.00 | ~$1,798 |
| **Memory Optimized E-Series** |
| E4  | 4  | 32  | 1.26 | ~$283 |
| E8  | 8  | 64  | 2.52 | ~$566 |
| E16 | 16 | 128 | 5.04 | ~$1,132 |
| E32 | 32 | 256 | 10.07 | ~$2,264 |

\* Approximate USD pricing - varies by region

---

## Prerequisites

### Required Software

1. **PowerShell** (version 5.1 or higher)
   - Windows: Built-in
   - Mac/Linux: Install [PowerShell Core](https://docs.microsoft.com/powershell/scripting/install/installing-powershell)

2. **Azure CLI**
   - Install from: https://docs.microsoft.com/cli/azure/install-azure-cli
   - Verify: `az --version`

3. **Az.Accounts PowerShell Module**
   - Install: `Install-Module -Name Az.Accounts -Scope CurrentUser -Force`
   - Note: Script will check and prompt if missing

### Azure Permissions Required

The account running the script needs:

| Permission Role | Resource Scope | Purpose |
|----------------|----------------|---------|
| **Reader** | Resource Group containing Container Apps | Read app configurations and profiles |
| **Monitoring Reader** | Subscription or Resource Group | Access Azure Monitor metrics |

**Note:** You do NOT need Cost Management Reader for this tool (it calculates allocation percentages, not absolute costs).

### Important: Managed Device Considerations

If running on a company-managed device with **Conditional Access policies**:
- **Azure CLI authentication typically works** (uses browser-based auth)
- **Az PowerShell may fail** with "device must be managed" errors
- **This script supports Azure CLI-first authentication** to work around this

---

## Installation

### Option 1: Direct Download

1. Download the script files:
   - `Get-ACAEnvironmentCostBreakdown.ps1` (main script)
   - `Scripts/ACAMetricsHelper.ps1` (helper functions)

2. Place them in a folder maintaining the structure:
   ```
   your-folder/
   ├── Get-ACAEnvironmentCostBreakdown.ps1
   └── Scripts/
       └── ACAMetricsHelper.ps1
   ```

### Option 2: Git Clone (if provided via repository)

```powershell
git clone <repository-url>
cd ACA-Cost-Estimate
```

---

## Usage

### Step 1: Authenticate to Azure

```powershell
# Login with Azure CLI (recommended for managed devices)
az login

# Alternatively, if Az PowerShell works in your environment:
Connect-AzAccount
```

### Step 2: Run the Script

**Basic Usage** (analyzes last 24 hours):

```powershell
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "your-resource-group" `
    -EnvironmentName "your-container-app-environment"
```

**Analyze Last 7 Days:**

```powershell
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "your-resource-group" `
    -EnvironmentName "your-container-app-environment" `
    -StartDate (Get-Date).AddDays(-7) `
    -EndDate (Get-Date)
```

**Custom Allocation Weights:**

```powershell
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "your-resource-group" `
    -EnvironmentName "your-container-app-environment" `
    -CpuWeight 0.5 `
    -MemoryWeight 0.4 `
    -ReplicaTimeWeight 0.1
```

### Step 3: Review Results

The script outputs:

1. **Console Summary**: Per-profile and environment-wide cost allocation
2. **CSV File**: Detailed metrics saved to `ACA-CostBreakdown-{env}-{timestamp}.csv`

---

## Understanding the Output

### Console Output Example

```
===== COST ALLOCATION RESULTS =====

Workload Profile: production-d8 (D8, Cost Weight: 2.0)

  api-service
    Profile Allocation: 65.43%
    Environment-Wide Cost: 45.62%
    - CPU Usage: 70.25% (2.105 cores avg)
    - Memory Usage: 58.32% (9.33 GiB avg)
    - Replica Time: 60.00% (144 replica-hours)

  worker-service
    Profile Allocation: 34.57%
    Environment-Wide Cost: 24.15%
    - CPU Usage: 29.75% (0.893 cores avg)
    - Memory Usage: 41.68% (6.67 GiB avg)
    - Replica Time: 40.00% (96 replica-hours)

  Profile Total: 100% | Environment Total: 69.77%

Workload Profile: batch-d16 (D16, Cost Weight: 4.0)

  batch-processor
    Profile Allocation: 100%
    Environment-Wide Cost: 30.23%
    - CPU Usage: 100% (3.2 cores avg)
    - Memory Usage: 100% (12.5 GiB avg)
    - Replica Time: 100% (168 replica-hours)

  Profile Total: 100% | Environment Total: 30.23%

===== ENVIRONMENT-WIDE SUMMARY =====

  api-service (production-d8): 45.62%
  worker-service (production-d8): 24.15%
  batch-processor (batch-d16): 30.23%

  Total Environment Cost: 100%
```

### Key Metrics Explained

| Metric | Meaning |
|--------|---------|
| **Profile Allocation** | App's % of its workload profile's cost (sums to 100% per profile) |
| **Environment-Wide Cost** | App's % of total environment cost across all profiles |
| **CPU Usage** | % of profile's CPU consumed by this app |
| **Memory Usage** | % of profile's memory consumed by this app |
| **Replica Time** | % of total replica-hours this app ran |

### CSV Output Columns

- `AppName`: Container App name
- `WorkloadProfile`: Workload profile name
- `ProfileCostWeight`: Relative cost weight of profile SKU
- `AvgCpuCores`: Average CPU cores used
- `AvgMemoryGiB`: Average memory (GiB) used
- `AvgReplicas`: Average number of replicas
- `ReplicaHours`: Total replica-hours in period
- `CpuUsagePercent`: % of profile CPU used
- `MemoryUsagePercent`: % of profile memory used
- `ReplicaTimePercent`: % of profile replica-time used
- `ProfileAllocationPercent`: % cost within profile
- `EnvironmentCostPercent`: % cost across environment

---

## Calculating Actual Costs

The script provides **allocation percentages**. To get actual dollar amounts:

### Step 1: Get Actual Costs from Azure Portal

1. Navigate to: **Cost Management + Billing** → **Cost Analysis**
2. Set filters:
   - **Date range**: Match your analysis period
   - **Resource group**: Your Container Apps resource group
   - **Resource type**: `Microsoft.App/managedEnvironments`
3. Note the total cost for each workload profile

### Step 2: Calculate Per-App Costs

Multiply the environment-wide percentage by total environment cost:

**Example:**
- Total environment cost (7 days): **$1,400**
- `api-service` environment-wide allocation: **45.62%**
- `api-service` cost: $1,400 × 45.62% = **$638.68**

### Step 3: Export for Reporting

```powershell
# Load CSV and add actual costs
$results = Import-Csv ".\ACA-CostBreakdown-*.csv"
$totalCost = 1400  # Replace with actual cost from Azure

$results | ForEach-Object {
    $_ | Add-Member -NotePropertyName "ActualCost" -NotePropertyValue ([Math]::Round(($_.EnvironmentCostPercent / 100) * $totalCost, 2))
}

$results | Export-Csv ".\ACA-CostBreakdown-WithActualCosts.csv" -NoTypeInformation
```

---

## Troubleshooting

### "Not logged in to Azure"

**Solution:**
```powershell
az login
# If Azure CLI login fails, try:
Connect-AzAccount -UseDeviceAuthentication
```

### "Your admin requires the device to be managed"

This occurs with Conditional Access policies on managed devices.

**Solution:** Use Azure CLI authentication (already built into script):
```powershell
az login  # This usually works even when Connect-AzAccount fails
```

The script automatically detects and uses Azure CLI tokens.

### "No dedicated workload profiles found"

Your environment uses only **Consumption profiles**. 

**Note:** Consumption profiles are billed per-replica directly in Azure billing, so cost allocation across apps is unnecessary. This tool is designed for **Dedicated profiles** (D4-D32, E4-E32) where multiple apps share infrastructure and costs need to be allocated.

**To analyze Consumption profiles anyway** (not recommended):
```powershell
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-sub-id" `
    -ResourceGroupName "your-rg" `
    -EnvironmentName "your-env" `
    -OnlyDedicated:$false
```

### "Unused Dedicated Workload Profiles" Warning

If you see this warning:
```
⚠️  COST WARNING: Unused Dedicated Workload Profiles
Profile: production-d8 running with 0 applications
Impact: You are paying for this dedicated profile even though no apps are using it.
```

**This means:** You have dedicated workload profiles provisioned but no Container Apps are running on them. **You're still being charged** for these idle profiles.

**Solution:** Delete unused profiles to stop charges:
```powershell
az containerapp env workload-profile delete `
    --name <profile-name> `
    --resource-group <your-rg> `
    --environment-name <your-env>
```

### "No metrics returned"

**Possible causes:**
1. Apps weren't running during analysis period
2. Metrics not yet available (wait 5-10 minutes after deployment)
3. Missing Monitoring Reader permission

**Solution:**
- Check apps were active: `az containerapp list --resource-group <rg> --output table`
- Verify permissions: Ask admin to grant **Monitoring Reader** role
- Try a different time range: `-StartDate (Get-Date).AddHours(-6)`

### "Unknown workload profile type"

**Message:** `WARNING: Unknown workload profile type 'X' for profile 'Y'. Skipping this profile.`

**Cause:** The workload profile uses an unsupported or custom SKU type.

**Solution:**
1. Check the profile configuration:
   ```powershell
   az containerapp env show --name <env> --resource-group <rg> --query "properties.workloadProfiles"
   ```
2. Verify the `workloadProfileType` is one of: D4, D8, D16, D32, E4, E8, E16, E32, or Consumption
3. If using a newer SKU not yet supported, contact support to update the script's cost weights table

### "cryptography backend.py" warning

This is **harmless** - it's from Azure CLI's Python libraries (not your script). It's a performance notice about 32-bit vs 64-bit Python.

**Full warning message:**
```
D:\a\_work\1\s\build_scripts\windows\artifacts\cli\Lib\site-packages\cryptography/hazmat/backends/openssl/backend.py:8: 
UserWarning: You are using cryptography on a 32-bit Python on a 64-bit Windows Operating System. 
Cryptography will be significantly faster if you switch to using a 64-bit Python.
```

**Impact:** None - the script runs correctly, just slightly slower for Azure CLI's internal operations.

**Recommended Fix:** Install the 64-bit version of Azure CLI:
1. Uninstall current Azure CLI: Settings → Apps → Azure CLI → Uninstall
2. Download latest Azure CLI from: https://aka.ms/installazurecliwindows
3. Run the MSI installer (installs 64-bit version by default)
4. Verify: `az --version` (should no longer show the warning)

**Alternative:** Ignore the warning - it doesn't affect functionality or results.

---

## Best Practices

### 1. Analysis Frequency

| Frequency | Use Case |
|-----------|----------|
| **Daily** | Active cost monitoring, rapid feedback |
| **Weekly** | Standard operational reviews |
| **Monthly** | Trend analysis, budgeting, chargebacks |

### 2. Time Range Selection

- **Shorter periods (1-3 days)**: Quick checks, troubleshooting
- **Longer periods (7-30 days)**: Accurate averages, smooths out variability
- **Avoid very short periods (<6 hours)**: Metrics may be incomplete

### 3. Validating Results

Always check the validation section:
```
✓ Profile 'production-d8' allocation: 100%
✓ Environment-wide total allocation: 100%
```

If you see `⚠` warnings, percentages don't sum to 100% - review for data quality issues.

### 4. Handling Multiple Environments

Run the script separately for each environment:

```powershell
$environments = @("prod-env", "staging-env", "dev-env")
foreach ($env in $environments) {
    .\Get-ACAEnvironmentCostBreakdown.ps1 `
        -SubscriptionId "your-sub-id" `
        -ResourceGroupName "your-rg" `
        -EnvironmentName $env
}
```

### 5. Automating with Azure Automation

For scheduled reporting, deploy as Azure Automation runbook:
1. Upload script to Automation Account
2. Configure Managed Identity with required permissions
3. Schedule daily/weekly runs
4. Store CSV outputs in Azure Storage

---

## Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **Consumption profiles not analyzed** | Only dedicated profiles supported | Expected - Consumption already billed per-replica |
| **No direct cost data** | Calculates percentages, not dollar amounts | Multiply by actual costs from Cost Management |
| **Metric retention (93 days)** | Can't analyze periods >93 days old | Export metrics separately for long-term storage |
| **Platform overhead not attributed** | Some infrastructure costs unallocated | Acceptable for relative comparison |

---

## Support & Feedback

### Common Questions

**Q: Can I change the allocation weights?**  
A: Yes, use `-CpuWeight`, `-MemoryWeight`, `-ReplicaTimeWeight` parameters (must sum to 1.0).

**Q: Does this work with GPU profiles?**  
A: Not currently - GPU profiles use different pricing. Contact support if needed.

**Q: Can I run this on Linux/Mac?**  
A: Yes, install PowerShell Core and Azure CLI for your platform.

**Q: Is this officially supported by Microsoft?**  
A: This is a community/partner tool. For official support, contact Azure Support.

### Providing Feedback

When reporting issues, include:
1. PowerShell version: `$PSVersionTable.PSVersion`
2. Azure CLI version: `az --version`
3. Error message (full output)
4. Anonymized environment details (# of apps, profiles)

---

## Appendix: Parameters Reference

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `SubscriptionId` | string | Yes | - | Azure subscription GUID |
| `ResourceGroupName` | string | Yes | - | Resource group containing environment |
| `EnvironmentName` | string | Yes | - | Container Apps Environment name |
| `StartDate` | DateTime | No | 24 hours ago | Analysis period start |
| `EndDate` | DateTime | No | Now | Analysis period end |
| `CpuWeight` | double | No | 0.6 | CPU usage weight (0-1) |
| `MemoryWeight` | double | No | 0.3 | Memory usage weight (0-1) |
| `ReplicaTimeWeight` | double | No | 0.1 | Replica runtime weight (0-1) |
| `OnlyDedicated` | switch | No | True | Only analyze Dedicated profiles (skip Consumption) |
| `OutputPath` | string | No | Current directory | CSV output folder |

**Notes:** 
- Weights must sum to 1.0 exactly
- `-OnlyDedicated` defaults to `$true` because Consumption profiles have individual billing and don't need cost allocation

---

## Version History

**v1.0** (January 2026)
- Initial release
- Support for D4-D32 and E4-E32 profiles
- Multi-profile cost weighting
- Azure CLI authentication support
- Environment-wide allocation calculation

---

## License

This tool is provided as-is for cost analysis purposes. No warranty expressed or implied.
