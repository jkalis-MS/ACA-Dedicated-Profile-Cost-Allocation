# Azure Container Apps Cost Breakdown Tool

PowerShell CLI tool for allocating costs across Container Apps sharing Dedicated Workload Profiles.

## Quick Start

```powershell
# Login
Connect-AzAccount
az login

# Run analysis
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "your-sub-id" `
    -ResourceGroupName "your-rg" `
    -EnvironmentName "your-env"
```

See [QUICKSTART.md](QUICKSTART.md) for detailed setup instructions.

## What It Does

Analyzes Azure Container Apps on shared Dedicated Workload Profiles and calculates what percentage of profile costs should be attributed to each app based on:
- CPU usage (60% weight)
- Memory usage (30% weight)  
- Replica runtime (10% weight)

## Project Structure

```
ACA-Cost-Estimate/
├── Get-ACAEnvironmentCostBreakdown.ps1    # Main script
├── Scripts/
│   └── ACAMetricsHelper.ps1               # Helper functions
├── config.example.json                     # Configuration template
├── README.md                               # Full documentation
├── QUICKSTART.md                           # Quick start guide
└── EXAMPLE.md                              # Example walkthrough
```

## Requirements

- PowerShell 7+ (or 5.1+)
- Azure CLI
- Azure PowerShell (Az.Accounts module)
- Azure permissions: Reader + Monitoring Reader

## Documentation

- **[README.md](README.md)** - Complete documentation, parameters, formulas
- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[EXAMPLE.md](EXAMPLE.md)** - Detailed example with sample data

## Output

- Console summary with cost allocation percentages per app
- CSV export with detailed metrics
- Validation that allocations sum to 100% per profile

## Current Limitations

- Calculates allocation percentages only (not actual cost amounts)
- Azure Cost Management API integration planned for Phase 2
- Dedicated Workload Profiles only (Consumption profiles excluded)

## Roadmap

- ✅ Phase 1: Cost allocation calculation (Current)
- ⬜ Phase 2: Azure Cost Management API integration
- ⬜ Phase 3: Grafana/Power BI visualization

## License

MIT
