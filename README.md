# Azure Container Apps Cost Breakdown Tool

A PowerShell CLI tool that calculates cost allocation percentages for Azure Container Apps sharing Dedicated Workload Profiles.

## Overview

When multiple Container Apps share Dedicated Workload Profiles (D4, D8, E4, etc.), Azure bills at the **profile level**, not per app. This tool analyzes actual resource usage (CPU, memory, replica runtime) to fairly allocate costs across applications.

### Key Features

✅ **Reserved capacity allocation** - Uses configured CPU/Memory × minReplicas  
✅ **Cross-resource group support** - Analyzes all apps in an environment, regardless of RG  
✅ **Pricing-based weights** - Derived from Azure pricing ($0.0571/vCPU, $0.0050/GiB)  
✅ Multi-profile cost allocation with SKU-aware weighting  
✅ CSV export with detailed metrics  
✅ Pure PowerShell - no Azure Monitor calls needed  
✅ Works with Azure CLI authentication  

## Quick Start

### Prerequisites

- **PowerShell 5.1+** or **PowerShell 7+**
- **Azure CLI** - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **Azure Permissions**: Reader + Monitoring Reader on Container Apps resources

### Installation

```powershell
# Clone the repository
git clone https://github.com/jkalis-MS/ACA-Dedicated-Profile-Cost-Allocation.git
cd ACA-Dedicated-Profile-Cost-Allocation

# Login to Azure
az login
```

### Basic Usage

```powershell
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-subscription-id" `
    -EnvironmentName "your-container-app-env"
```
### Custom Allocation Weights
```powershell
# Default weights are based on Azure pricing ($0.0571/vCPU, $0.0050/GiB)
# CPU=0.92, Memory=0.08 - adjust if needed
-CpuWeight 0.85 -MemoryWeight 0.15
```

### Analyze Only Dedicated Profiles
```powershell
-OnlyDedicated $true  # Default behavior
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `SubscriptionId` | ✓ | - | Azure Subscription ID |
| `EnvironmentName` | ✓ | - | Container Apps Environment name |
| `ResourceGroupName` | | (discovered) | Resource Group name (optional - evaluating all Container Apps for provided Environment if not provided) |
| `StartDate` | | 24h ago | Analysis start time |
| `EndDate` | | Now | Analysis end time |
| `AllocationMode` | | Reserved | `Reserved` = configured resources, `Actual` = real usage |
| `CpuWeight` | | 0.92 | CPU usage weight (based on $0.0571/vCPU-hour) |
| `MemoryWeight` | | 0.08 | Memory usage weight (based on $0.0050/GiB-hour) |
| `OnlyDedicated` | | $true | Skip Consumption profiles |
| `OutputPath` | | ./ | CSV output directory |

**Note:** CPU + Memory weights must sum to 1.0. Replica time is used as a multiplier (see Cost Allocation Model below).

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Not logged in" | Run `az login` |
| "Environment not found" | Verify subscription, resource group, environment names |
| "No dedicated profiles found" | Environment uses only Consumption profiles |
| "No metrics returned" | Check time range and Monitoring Reader permissions |

See [CUSTOMER_GUIDE.md](CUSTOMER_GUIDE.md#troubleshooting) for detailed troubleshooting.

## How It Works

The script:
1. Discovers environment by name across the subscription
2. Extracts workload profiles with SKU types from environment properties
3. Lists all container apps targeting the environment (any resource group)
4. Reads configured CPU/Memory and minReplicas from each app
5. Calculates cost allocation using the 3-step model
6. Exports detailed CSV report

**No Azure Monitor Required:** Uses app configuration data directly, making it faster and simpler.

## Cost Allocation Model

The tool uses a **3-step resource-cost weighted model** that reflects actual Azure pricing:

| Meter | Azure Price | Weight |
|-------|-------------|--------|
| vCPU | $0.0571/hour | 0.92 (92%) |
| Memory (GiB) | $0.0050/hour | 0.08 (8%) |

**Allocation Formula:**

```
Step 1: ResourceCostShare = (CPU% × 0.92) + (Memory% × 0.08)
Step 2: FinalCostShare = ResourceCostShare × ReplicaTime%
Step 3: ProfileAllocation = Normalize to 100%
```

**Why this model?**
- **Pricing-based weights**: CPU costs ~11x more than memory per unit
- **Replica time as multiplier**: An app running 50% of the time pays 50% of its resource-proportional cost
- **Fair allocation**: Apps are charged based on both *what resources they use* and *how long they use them*

## Limitations

- **Percentages only** - No direct dollar amounts
- **Dedicated profiles only** - Consumption profiles billed separately per-replica

## Roadmap

**Phase 1** (✅ Complete)  
- Multi-profile cost allocation with SKU weighting  
- CSV export and configurable formulas  

## License

MIT License

## Related Resources

- [Azure Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Workload Profiles Documentation](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview)
- [Azure Monitor Metrics](https://learn.microsoft.com/azure/azure-monitor/essentials/metrics-supported#microsoftappcontainerapps)

- [Workload Profiles Documentation](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview)
- [Azure Monitor Metrics](https://learn.microsoft.com/azure/azure-monitor/essentials/metrics-supported#microsoftappcontainerapps)
- [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/)
