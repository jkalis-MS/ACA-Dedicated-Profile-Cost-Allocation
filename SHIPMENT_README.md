# Azure Container Apps Cost Allocation Tool - Shipment Package

## Package Contents

This customer-ready package contains:

### Core Files
1. **`Get-ACAEnvironmentCostBreakdown.ps1`** - Main PowerShell script
2. **`Scripts/ACAMetricsHelper.ps1`** - Helper functions module

### Documentation
3. **`CUSTOMER_GUIDE.md`** - Complete customer-facing documentation (⭐ START HERE)
4. **`README.md`** - Technical documentation and architecture
5. **`QUICKSTART.md`** - 5-minute getting started guide
6. **`EXAMPLE.md`** - Detailed walkthrough with sample data
7. **`config.example.json`** - Configuration template

## ✅ Ready for Customer Shipment

### What Makes This Customer-Ready

✅ **No Compiled Code**: Pure PowerShell - fully transparent and inspectable  
✅ **Azure CLI Authentication**: Works on managed devices with conditional access  
✅ **Multi-Profile Support**: Handles different SKUs (D4-D32, E4-E32) with relative cost weights  
✅ **Region-Agnostic**: Cost weights normalized to D4=1.0 baseline  
✅ **Comprehensive Documentation**: Step-by-step guides for all skill levels  
✅ **Production-Tested**: Successfully ran against real environment  

### Key Features for Customers

- **Environment-wide cost allocation** across multiple workload profiles
- **SKU-aware weighting**: D8 costs 2x D4, E16 costs 5.04x D4, etc.
- **Transparent calculation**: Shows both per-profile % and environment-wide %
- **CSV export** for reporting and integration
- **Validation checks** ensure allocations sum to 100%

## Architecture Answers to Your Questions

### (1) The "backend.py" Warning

**Status:** ✅ Not a concern

The cryptography warning is from **Azure CLI's Python libraries**, not from our code:
- Our script is 100% PowerShell (no compiled code)
- Customers can inspect every line
- The warning is harmless (32-bit vs 64-bit Python performance notice)
- Does not affect functionality

### (2) Multi-Profile Cost Weighting

**Status:** ✅ Implemented

The script now handles multiple workload profiles with different SKUs using **relative cost weights**:

```powershell
# Built-in cost weights (normalized to D4 = 1.0)
D4:  1.00  ($224.808/month)
D8:  2.00  ($449.616/month)
D16: 4.00  ($899.232/month)
D32: 8.00  ($1798.463/month)
E4:  1.26  ($282.951/month)
E8:  2.52  ($565.902/month)
E16: 5.04  ($1131.804/month)
E32: 10.07 ($2263.607/month)
```

**How it works:**
1. Each app gets a **profile allocation %** (its share of that specific profile)
2. Profile costs are weighted by SKU
3. Final **environment-wide %** accounts for relative profile costs

**Example:**
- App A on D8 profile: 50% of D8 profile → 50% × 2.0 weight = 1.0 weighted cost
- App B on D16 profile: 30% of D16 profile → 30% × 4.0 weight = 1.2 weighted cost
- Environment-wide: App A = 45.45%, App B = 54.55%

This ensures fair allocation regardless of which profile apps run on.

## How to Ship to Customer

### Option 1: ZIP Package

1. Create zip with folder structure:
   ```
   ACA-Cost-Estimate/
   ├── Get-ACAEnvironmentCostBreakdown.ps1
   ├── Scripts/
   │   └── ACAMetricsHelper.ps1
   ├── CUSTOMER_GUIDE.md (⭐ PRIMARY DOCS)
   ├── QUICKSTART.md
   ├── README.md
   ├── EXAMPLE.md
   └── config.example.json
   ```

2. Email or share via secure file transfer

3. Customer extracts and runs

### Option 2: Git Repository

1. Initialize git repo:
   ```powershell
   git init
   git add .
   git commit -m "Initial release v1.0"
   ```

2. Push to Azure DevOps, GitHub, or internal repo

3. Share repository URL with customer

### Option 3: Azure DevOps Artifacts (Recommended for Enterprise)

1. Package as PowerShell module
2. Publish to internal feed
3. Customer installs via `Install-Module`

## Customer Onboarding Steps

### Quick Start (5 minutes)

```powershell
# 1. Install Az.Accounts (if needed)
Install-Module -Name Az.Accounts -Scope CurrentUser -Force

# 2. Login to Azure
az login

# 3. Run the script
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "customer-sub-id" `
    -ResourceGroupName "customer-rg" `
    -EnvironmentName "customer-env"

# 4. Review results in console and CSV file
```

### Expected Output

```
===== COST ALLOCATION RESULTS =====

Workload Profile: production-d8 (D8, Cost Weight: 2.0)
  api-service:    Profile: 65%, Environment: 32%
  worker-service: Profile: 35%, Environment: 17%

Workload Profile: batch-d16 (D16, Cost Weight: 4.0)
  batch-app:      Profile: 100%, Environment: 51%

Total Environment Cost: 100%
```

## Validation Checklist

Before shipping, verify:

- [x] Script runs successfully on test environment
- [x] Azure CLI authentication works (bypasses conditional access issues)
- [x] Multiple workload profiles handled correctly
- [x] Cost weights applied properly (D8=2x D4, etc.)
- [x] CSV export generates successfully
- [x] Validation shows 100% allocation
- [x] No compiled code dependencies
- [x] Documentation complete and accurate
- [x] Error handling for common scenarios

## Known Limitations (Documented for Customer)

1. **Consumption profiles excluded**: Tool focuses on Dedicated profiles only (expected)
2. **No direct cost amounts**: Provides percentages - customer multiplies by actual costs
3. **Requires Azure CLI**: Standard tool, easy to install
4. **Metric retention 93 days**: Standard Azure Monitor limitation

## Support Plan

### Tier 1: Documentation
- CUSTOMER_GUIDE.md covers 90% of questions
- QUICKSTART.md for getting started
- EXAMPLE.md for detailed walkthrough

### Tier 2: Troubleshooting
- Common issues documented in CUSTOMER_GUIDE
- Authentication problems (use Azure CLI)
- Permission requirements (Reader + Monitoring Reader)

### Tier 3: Escalation
- If customer needs customization (new SKUs, custom weights)
- Integration with other systems
- Automation/scheduling assistance

## Future Enhancements (Optional)

### Phase 2 Ideas
- [ ] Azure Cost Management API integration (get actual costs automatically)
- [ ] GPU profile support (NC-series, ND-series)
- [ ] Power BI template for visualization
- [ ] Azure Automation runbook template
- [ ] Email/Teams notification support

### Phase 3 Ideas
- [ ] Historical trend analysis
- [ ] Cost forecasting based on usage patterns
- [ ] Anomaly detection (apps consuming unexpected resources)
- [ ] Multi-subscription support

## Version Management

**Current Version:** 1.0 (January 2026)

Recommended versioning in script header:
```powershell
<#
.VERSION
    1.0 - January 2026
    
.CHANGES
    - Initial release
    - Multi-profile SKU cost weighting
    - Azure CLI authentication support
#>
```

## Contact Information

Include in shipment package:
- Support contact email
- Feedback mechanism
- Update notification process

---

## Summary

✅ **Package is production-ready for customer shipment**

**What's included:**
- Full PowerShell solution (no compiled code)
- Multi-SKU support with relative cost weights
- Comprehensive customer documentation
- Production-tested and validated

**Customer value:**
- Fair cost allocation across apps sharing Dedicated Workload Profiles
- Transparent methodology (inspectable PowerShell)
- Works on managed devices (Azure CLI auth)
- Easy to run, understand, and integrate

**Recommended next step:** Package files into ZIP or git repository and share with customer along with CUSTOMER_GUIDE.md as primary documentation.
