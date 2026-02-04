# Azure Container Apps Cost Breakdown Tool

A PowerShell tool that calculates cost allocation percentages for Azure Container Apps sharing Dedicated Workload Profiles.

## What It Does

When multiple Container Apps share Dedicated Workload Profiles (D4, D8, E4, etc.), Azure bills at the **profile level**, not per app. This script helps to allocate costs across applications based on their scale settings.

**Key Features:**
- Reserved capacity allocation (configured CPU/Memory × minReplicas)
- Cross-resource group support (finds all apps in an environment)
- Pricing-based weights derived from Azure pricing
- CSV export with detailed metrics

## Cost Allocation Model

The tool uses a **3-step model** based on actual Azure pricing:

| Meter | Azure Price | Weight |
|-------|-------------|--------|
| vCPU | $0.0571/hour | 92% |
| Memory (GiB) | $0.0050/hour | 8% |

**Formula:**
```
Step 1: ResourceCostShare = (CPU% × 0.92) + (Memory% × 0.08)
Step 2: WeightedShare = ResourceCostShare × ReplicaPercent
Step 3: Normalize to 100% per profile
```

**Example:** An app with 50% of profile CPU, 30% of memory, and 2 of 4 total replicas:
- ResourceCostShare = (0.50 × 0.92) + (0.30 × 0.08) = 0.484
- WeightedShare = 0.484 × 0.50 = 0.242
- Final allocation after normalization with other apps

## Prerequisites

- **PowerShell 5.1+** or **PowerShell 7+**
- **Azure CLI** - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **Permissions**: Reader on Container Apps resources

## Usage

```powershell
# Login to Azure
az login

# Basic usage
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-subscription-id" `
    -EnvironmentName "your-container-app-env"

# With custom weights
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-subscription-id" `
    -EnvironmentName "your-container-app-env" `
    -CpuWeight 0.85 -MemoryWeight 0.15
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `SubscriptionId` | ✓ | - | Azure Subscription ID |
| `EnvironmentName` | ✓ | - | Container Apps Environment name |
| `CpuWeight` | | 0.92 | CPU weight (based on $0.0571/vCPU-hour) |
| `MemoryWeight` | | 0.08 | Memory weight (based on $0.0050/GiB-hour) |
| `OnlyDedicated` | | $true | Skip Consumption profiles |
| `OutputPath` | | ./ | CSV output directory |

> **Note:** CpuWeight + MemoryWeight must equal 1.0

## Example Output

```
===== COST ALLOCATION RESULTS =====

Profile: dedicated-d4 (D4)
  api-service         CPU: 1.00 cores  Mem: 2.00 GiB  Replicas: 2  → 55.23%
  worker-service      CPU: 0.50 cores  Mem: 1.00 GiB  Replicas: 2  → 44.77%
  Profile Total: 100.00%

✓ Results exported to: .\ACA-CostBreakdown-my-env-20260204-143052.csv
```

## Calculating Actual Costs

1. Get profile costs from **Azure Portal → Cost Management → Cost Analysis**
2. Filter by your Container Apps Environment
3. Multiply profile cost by each app's allocation percentage

**Example:** If profile-d4 costs $672/month and api-service has 55.23% allocation:
- api-service cost = $672 × 0.5523 = **$371.15**

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Not logged in" | Run `az login` |
| "Environment not found" | Verify subscription and environment name |
| "No dedicated profiles" | Environment uses only Consumption profiles |
| Apps showing 0% | Check that minReplicas > 0 in app config |

## License

MIT License

## Resources

- [Azure Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Workload Profiles Documentation](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview)
