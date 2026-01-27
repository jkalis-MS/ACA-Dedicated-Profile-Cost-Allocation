# Example: Testing the Script

## Test Environment Setup

Let's say you have:
- **Subscription**: `12345678-1234-1234-1234-123456789abc`
- **Resource Group**: `rg-containerapp-prod`
- **Environment**: `aca-prod-env`
- **Apps on Dedicated Profile**:
  - `api-service` (on profile: D4)
  - `worker-service` (on profile: D4)
  - `batch-processor` (on profile: D8)

## Run the Analysis

```powershell
# Connect to Azure
Connect-AzAccount
az login

# Run for last 7 days
.\Get-ACAEnvironmentCostBreakdown.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -ResourceGroupName "rg-containerapp-prod" `
    -EnvironmentName "aca-prod-env" `
    -StartDate (Get-Date).AddDays(-7) `
    -EndDate (Get-Date)
```

## Expected Output

```
===== Azure Container Apps Cost Breakdown Tool =====
Subscription: 12345678-1234-1234-1234-123456789abc
Resource Group: rg-containerapp-prod
Environment: aca-prod-env
Analysis Period: 2026-01-16 10:00 to 2026-01-23 10:00
Allocation Weights: CPU=0.6, Memory=0.3, ReplicaTime=0.1

[1/7] Setting Azure subscription context...
   ✓ Connected to subscription: Production

[2/7] Retrieving Container Apps Environment details...
   ✓ Environment: aca-prod-env
   Location: eastus

[3/7] Retrieving Workload Profiles...
   ✓ Found 2 dedicated workload profile(s):
     - profile-d4: D4 (Min: 1, Max: 5)
     - profile-d8: D8 (Min: 1, Max: 3)

[4/7] Retrieving Container Apps...
   ✓ Found 3 app(s) on dedicated profiles:
     - api-service: Profile=profile-d4
     - worker-service: Profile=profile-d4
     - batch-processor: Profile=profile-d8

[5/7] Collecting metrics from Azure Monitor...
   This may take a few minutes...
   Processing: api-service...
     ✓ CPU: 1.850 cores, Memory: 8.25 GiB, Replicas: 3.2
   Processing: worker-service...
     ✓ CPU: 0.950 cores, Memory: 4.75 GiB, Replicas: 2.1
   Processing: batch-processor...
     ✓ CPU: 3.200 cores, Memory: 12.50 GiB, Replicas: 1.5
   ✓ Metrics collection complete

[6/7] Calculating cost allocation...
   ✓ Cost allocation calculated

[7/7] Generating report...

===== COST ALLOCATION RESULTS =====

Workload Profile: profile-d4 (D4)

  api-service
    Cost Allocation: 66.08%
    - CPU Usage: 66.07% (1.85 cores avg)
    - Memory Usage: 63.46% (8.25 GiB avg)
    - Replica Time: 60.38% (512.1 replica-hours)

  worker-service
    Cost Allocation: 33.92%
    - CPU Usage: 33.93% (0.95 cores avg)
    - Memory Usage: 36.54% (4.75 GiB avg)
    - Replica Time: 39.62% (335.9 replica-hours)

  Total Allocation: 100.00%

Workload Profile: profile-d8 (D8)

  batch-processor
    Cost Allocation: 100.00%
    - CPU Usage: 100.00% (3.2 cores avg)
    - Memory Usage: 100.00% (12.5 GiB avg)
    - Replica Time: 100.00% (252 replica-hours)

  Total Allocation: 100.00%

✓ Results exported to: .\ACA-CostBreakdown-aca-prod-env-20260123-100530.csv

===== VALIDATION =====
✓ Profile 'profile-d4' total allocation: 100.00%
✓ Profile 'profile-d8' total allocation: 100.00%

Analysis complete!
```

## CSV Output

File: `ACA-CostBreakdown-aca-prod-env-20260123-100530.csv`

```csv
AppName,WorkloadProfile,AvgCpuCores,AvgMemoryGiB,AvgReplicas,ReplicaHours,CpuUsagePercent,MemoryUsagePercent,ReplicaTimePercent,AllocatedCostPercent
api-service,profile-d4,1.850,8.25,3.2,512.1,66.07,63.46,60.38,66.08
worker-service,profile-d4,0.950,4.75,2.1,335.9,33.93,36.54,39.62,33.92
batch-processor,profile-d8,3.200,12.50,1.5,252.0,100.00,100.00,100.00,100.00
```

## Calculating Actual Costs

Now get actual costs from Azure Portal:

1. Go to: **Cost Management + Billing** → **Cost Analysis**
2. Filter:
   - **Date range**: Jan 16 - Jan 23, 2026
   - **Resource group**: rg-containerapp-prod
   - **Resource type**: Microsoft.App/managedEnvironments
3. Find costs for each workload profile:
   - `profile-d4`: $672.00 (168 hours × 1 instance × $4/hour)
   - `profile-d8`: $1,176.00 (168 hours × 1 instance × $7/hour)

### Calculate Per-App Costs

**Profile D4 Apps:**
- `api-service`: $672 × 66.08% = **$444.06**
- `worker-service`: $672 × 33.92% = **$227.94**

**Profile D8 Apps:**
- `batch-processor`: $1,176 × 100% = **$1,176.00**

**Total Environment Cost**: $444.06 + $227.94 + $1,176.00 = **$1,848.00**

## Interpretation

- **api-service** consumed 66% of profile-d4 resources, primarily due to higher CPU usage
- **worker-service** consumed 34% of profile-d4 resources
- **batch-processor** is the only app on profile-d8, so gets 100% of that cost
- All allocations validate correctly (sum to 100% per profile)

## Actionable Insights

Based on these results, you might:

1. **Optimize api-service**: It's consuming 2x resources of worker-service
   - Review CPU usage patterns
   - Consider right-sizing or optimization

2. **Consider consolidation**: If workloads permit, moving batch-processor to share a profile could reduce costs

3. **Monitor trends**: Run this weekly to track changes over time

4. **Budget allocation**: You can now allocate the $1,848 monthly environment cost across teams/projects accurately
