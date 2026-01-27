# Azure Container Apps Cost Breakdown Tool

A PowerShell CLI tool that calculates cost allocation percentages for Azure Container Apps sharing Dedicated Workload Profiles.

## Overview

When multiple Container Apps share Dedicated Workload Profiles (D4, D8, E4, etc.), Azure bills at the **profile level**, not per app. This tool analyzes actual resource usage (CPU, memory, replica runtime) to fairly allocate costs across applications.

### Key Features

✅ Multi-profile cost allocation with SKU-aware weighting  
✅ Configurable allocation formula (CPU, memory, replica-time)  
✅ CSV export with detailed metrics  
✅ Pure PowerShell - no compiled code  
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
    -ResourceGroupName "your-resource-group" `
    -EnvironmentName "your-container-app-env"
```

### Example Output

```
Workload Profile: production-d8 (D8, Cost Weight: 2.0)

  api-service
    Profile Allocation: 65.43%
    Environment-Wide Cost: 45.62%
    - CPU Usage: 70.25% (2.1 cores avg)
    - Memory Usage: 58.32% (9.3 GiB avg)
    - Replica Time: 60.00% (144 replica-hours)
```

Results are exported to CSV: `ACA-CostBreakdown-{env}-{timestamp}.csv`

## Cost Allocation Formula

**Per Profile:**
```
App % = (CPU% × 0.6) + (Memory% × 0.3) + (ReplicaTime% × 0.1)
```

**Environment-Wide (Multiple Profiles):**
```
App % = Profile Cost Weight × App Profile % / Total Weighted Cost
```

### SKU Cost Weights

| SKU | vCPU | RAM | Weight | Monthly Cost* |
|-----|------|-----|--------|---------------|
| D4  | 4    | 16  | 1.00   | ~$225         |
| D8  | 8    | 32  | 2.00   | ~$450         |
| D16 | 16   | 64  | 4.00   | ~$899         |
| D32 | 32   | 128 | 8.00   | ~$1,798       |
| E4  | 4    | 32  | 1.26   | ~$283         |
| E8  | 8    | 64  | 2.52   | ~$566         |
| E16 | 16   | 128 | 5.04   | ~$1,132       |
| E32 | 32   | 256 | 10.07  | ~$2,264       |

*Approximate USD pricing

## Documentation

📘 **[CUSTOMER_GUIDE.md](CUSTOMER_GUIDE.md)** - Complete user guide with examples  
⚡ **[QUICKSTART.md](QUICKSTART.md)** - 5-minute setup guide  
📊 **[EXAMPLE.md](EXAMPLE.md)** - Detailed walkthrough with sample data  
📦 **[SHIPMENT_README.md](SHIPMENT_README.md)** - Packaging and delivery guide  

## Advanced Usage

### Custom Time Range (Last 7 Days)
```powershell
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId $subId `
    -ResourceGroupName $rg `
    -EnvironmentName $env `
    -StartDate (Get-Date).AddDays(-7) `
    -EndDate (Get-Date)
```

### Custom Allocation Weights
```powershell
# CPU-heavy weighting
-CpuWeight 0.7 -MemoryWeight 0.2 -ReplicaTimeWeight 0.1
```

### Analyze Only Dedicated Profiles
```powershell
-OnlyDedicated $true  # Default behavior
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `SubscriptionId` | ✓ | - | Azure Subscription ID |
| `ResourceGroupName` | ✓ | - | Resource Group name |
| `EnvironmentName` | ✓ | - | Container Apps Environment name |
| `StartDate` | | 24h ago | Analysis start time |
| `EndDate` | | Now | Analysis end time |
| `CpuWeight` | | 0.6 | CPU usage weight (0-1) |
| `MemoryWeight` | | 0.3 | Memory usage weight (0-1) |
| `ReplicaTimeWeight` | | 0.1 | Replica runtime weight (0-1) |
| `OnlyDedicated` | | $true | Skip Consumption profiles |
| `OutputPath` | | ./ | CSV output directory |

**Note:** Weights must sum to 1.0

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
1. Retrieves environment configuration via `az containerapp env show`
2. Extracts workload profiles with SKU types from environment properties
3. Collects CPU, memory, and replica metrics from Azure Monitor
4. Calculates weighted allocation percentages per profile
5. Applies SKU cost weights for environment-wide allocation
6. Exports detailed CSV report

**SKU Detection:** Uses `workloadProfileType` property from Azure, ensuring accurate cost weight application without relying on naming conventions.

## Limitations

- **Percentages only** - No direct dollar amounts (Azure Cost Management API integration planned for Phase 2)
- **Dedicated profiles only** - Consumption profiles billed separately per-replica
- **93-day metric retention** - Azure Monitor limitation

## Roadmap

**Phase 1** (✅ Complete)  
- Multi-profile cost allocation with SKU weighting  
- CSV export and configurable formulas  

**Phase 2** (Planned)  
- Azure Cost Management API integration  
- Actual dollar amounts  
- Multi-environment analysis  

**Phase 3** (Future)  
- Grafana dashboards  
- Power BI templates  
- Azure Automation scheduling  

## Contributing

Contributions welcome! Areas for improvement:
- Cost Management API integration
- Additional metrics (network, storage)
- Visualization improvements
- Unit tests

## License

MIT License

## Related Resources

- [Azure Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Workload Profiles Documentation](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview)
- [Azure Monitor Metrics](https://learn.microsoft.com/azure/azure-monitor/essentials/metrics-supported#microsoftappcontainerapps)

- [Workload Profiles Documentation](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview)
- [Azure Monitor Metrics](https://learn.microsoft.com/azure/azure-monitor/essentials/metrics-supported#microsoftappcontainerapps)
- [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/)
