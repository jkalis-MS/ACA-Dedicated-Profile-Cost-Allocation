<#
.SYNOPSIS
    Calculates cost breakdown by Container App across shared Dedicated Workload Profiles
    
.DESCRIPTION
    This script analyzes Azure Container Apps running on Dedicated Workload Profiles within
    a Container Apps Environment and calculates the percentage of cost attributable to each app
    based on actual resource usage (CPU, memory) and replica runtime.
    
.PARAMETER SubscriptionId
    Azure Subscription ID containing the Container Apps Environment
    
.PARAMETER ResourceGroupName
    Resource Group name containing the Container Apps Environment
    
.PARAMETER EnvironmentName
    Name of the Container Apps Environment to analyze
    
.PARAMETER StartDate
    Start date for metric collection (default: 24 hours ago)
    
.PARAMETER EndDate
    End date for metric collection (default: now)
    
.PARAMETER AllocationMode
    How to calculate resource usage for cost allocation (default: Reserved)
    - Reserved: Uses configured CPU/Memory from container app settings (recommended)
                Apps pay for what they reserve, regardless of actual usage
    - Actual:   Uses actual CPU/Memory consumption from Azure Monitor
                Apps pay based on real resource consumption
    
.PARAMETER CpuWeight
    Weight for CPU usage in allocation formula (default: 0.92)
    Based on Azure pricing: $0.0571/vCPU-hour
    
.PARAMETER MemoryWeight
    Weight for memory usage in allocation formula (default: 0.08)
    Based on Azure pricing: $0.0050/GiB-hour
    
.PARAMETER ReplicaTimeWeight
    DEPRECATED: Replica time is now used as a multiplier, not an additive weight.
    This parameter is kept for backward compatibility but ignored in the new model.
    
.PARAMETER OutputPath
    Path for output CSV file (default: current directory)
    
.EXAMPLE
    .\Get-ACAEnvironmentCostBreakdown.ps1 -SubscriptionId "xxxx" -ResourceGroupName "myRG" -EnvironmentName "myEnv"
    
.EXAMPLE
    .\Get-ACAEnvironmentCostBreakdown.ps1 -SubscriptionId "xxxx" -ResourceGroupName "myRG" -EnvironmentName "myEnv" -StartDate (Get-Date).AddDays(-7)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,
    
    [Parameter(Mandatory = $false)]
    [DateTime]$StartDate = (Get-Date).AddHours(-24),
    
    [Parameter(Mandatory = $false)]
    [DateTime]$EndDate = (Get-Date),
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Reserved", "Actual")]
    [string]$AllocationMode = "Reserved",
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1)]
    [double]$CpuWeight = 0.92,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1)]
    [double]$MemoryWeight = 0.08,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1)]
    [double]$ReplicaTimeWeight = 0.0,  # Deprecated: now used as multiplier
    
    [Parameter(Mandatory = $false)]
    [switch]$OnlyDedicated = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "."
)

$ErrorActionPreference = "Stop"

# Check for required modules
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Host "ERROR: Az.Accounts module is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install it using one of these methods:" -ForegroundColor Yellow
    Write-Host "  Option 1: Install-Module -Name Az.Accounts -Scope CurrentUser -Force" -ForegroundColor Cyan
    Write-Host "  Option 2: Install-Module -Name Az -Scope CurrentUser -Force" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Workload Profile relative cost weights (normalized to D4 = 1.0, region-agnostic)
# Based on Azure pricing: cost scales with vCPU count, E-series has memory premium
$workloadProfileCostWeights = @{
    "D4"  = 1.00
    "D8"  = 2.00
    "D16" = 4.00
    "D32" = 8.00
    "E4"  = 1.26
    "E8"  = 2.52
    "E16" = 5.04
    "E32" = 10.07
    "Consumption" = 0  # Consumption billed separately per replica
}

function Get-ProfileCostWeight {
    param(
        [string]$ProfileType
    )
    
    # Use workloadProfileType directly - it's always populated correctly from az containerapp env show
    if ($workloadProfileCostWeights.ContainsKey($ProfileType)) {
        return $workloadProfileCostWeights[$ProfileType]
    }
    
    # Return null if SKU not recognized
    return $null
}

# Validate CPU + Memory weights sum to 1.0 (ReplicaTimeWeight is deprecated)
$totalWeight = $CpuWeight + $MemoryWeight
if ([Math]::Abs($totalWeight - 1.0) -gt 0.001) {
    Write-Error "CPU and Memory weights must sum to 1.0. Current sum: $totalWeight"
    exit 1
}

if ($ReplicaTimeWeight -gt 0) {
    Write-Warning "ReplicaTimeWeight parameter is deprecated. Replica time is now used as a multiplier in the 3-step allocation model."
}

Write-Host "===== Azure Container Apps Cost Breakdown Tool =====" -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Environment: $EnvironmentName" -ForegroundColor Gray
Write-Host "Analysis Period: $($StartDate.ToString('yyyy-MM-dd HH:mm')) to $($EndDate.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
Write-Host "Allocation Mode: $AllocationMode ($(if ($AllocationMode -eq 'Reserved') { 'configured resources' } else { 'actual usage from Azure Monitor' }))" -ForegroundColor Gray
Write-Host "Allocation Weights: CPU=$CpuWeight, Memory=$MemoryWeight (ReplicaTime used as multiplier)" -ForegroundColor Gray
Write-Host "Analyze Only Dedicated Profiles: $OnlyDedicated" -ForegroundColor Gray
Write-Host ""

# Import helper functions
. "$PSScriptRoot\Scripts\ACAMetricsHelper.ps1"

# Step 1: Set Azure context
Write-Host "[1/7] Setting Azure subscription context..." -ForegroundColor Yellow
try {
    # Try Azure CLI first (works better with conditional access policies)
    $cliAccount = az account show 2>$null | ConvertFrom-Json
    
    if ($cliAccount) {
        # Azure CLI is authenticated, set the subscription
        az account set --subscription $SubscriptionId 2>$null | Out-Null
        $verifyAccount = az account show | ConvertFrom-Json
        Write-Host "   ✓ Connected via Azure CLI to subscription: $($verifyAccount.name)" -ForegroundColor Green
    } else {
        # Fall back to Az PowerShell if Azure CLI not available
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "   Not logged in. Please run one of:" -ForegroundColor Red
            Write-Host "     - az login" -ForegroundColor Yellow
            Write-Host "     - Connect-AzAccount" -ForegroundColor Yellow
            exit 1
        }
        
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        Write-Host "   ✓ Connected via Az PowerShell to subscription: $($context.Subscription.Name)" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to set Azure context: $_"
    exit 1
}

# Step 2: Get Container Apps Environment
Write-Host "[2/7] Retrieving Container Apps Environment details..." -ForegroundColor Yellow
$envResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.App/managedEnvironments/$EnvironmentName"

try {
    $environment = az containerapp env show `
        --name $EnvironmentName `
        --resource-group $ResourceGroupName `
        --subscription $SubscriptionId `
        --output json | ConvertFrom-Json
    
    if (-not $environment) {
        Write-Error "Environment not found: $EnvironmentName"
        exit 1
    }
    
    Write-Host "   ✓ Environment: $($environment.name)" -ForegroundColor Green
    Write-Host "   Location: $($environment.location)" -ForegroundColor Gray
} catch {
    Write-Error "Failed to retrieve environment: $_"
    exit 1
}

# Step 3: Get Workload Profiles (from environment object)
Write-Host "[3/7] Retrieving Workload Profiles..." -ForegroundColor Yellow
try {
    # Extract workload profiles from the environment object we already fetched
    $workloadProfiles = $environment.properties.workloadProfiles
    
    if (-not $workloadProfiles -or $workloadProfiles.Count -eq 0) {
        Write-Error "No workload profiles found in environment: $EnvironmentName"
        exit 1
    }
    
    # Filter profiles based on OnlyDedicated setting
    if ($OnlyDedicated) {
        # Exclude Consumption profiles - only analyze Dedicated profiles
        # Note: Consumption profile name is always "Consumption", dedicated profiles have custom names
        $dedicatedProfiles = $workloadProfiles | Where-Object { 
            $_.name -ne "Consumption" -and 
            $_.workloadProfileType -ne "Consumption"
        }
        
        if ($dedicatedProfiles.Count -eq 0) {
            Write-Warning "No dedicated workload profiles found in this environment."
            Write-Host "" -ForegroundColor Yellow
            Write-Host "This environment uses only Consumption profiles, which are billed per-replica." -ForegroundColor Yellow
            Write-Host "Cost allocation is not needed for Consumption profiles as they have individual pricing in Azure billing." -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Yellow
            Write-Host "To analyze Consumption profiles anyway, run with: -OnlyDedicated:`$false" -ForegroundColor Gray
            exit 0
        }
    } else {
        # Analyze all profiles
        $dedicatedProfiles = $workloadProfiles
    }
    
    Write-Host "   ✓ Found $($dedicatedProfiles.Count) dedicated workload profile(s):" -ForegroundColor Green
    
    foreach ($profile in $dedicatedProfiles) {
        $profileType = $profile.workloadProfileType
        $profileName = $profile.name
        $costWeight = Get-ProfileCostWeight -ProfileType $profileType
        
        if ($null -eq $costWeight) {
            Write-Warning "Unknown workload profile type '$profileType' for profile '$profileName'. Skipping this profile."
            continue
        }
        
        $minNodes = if ($profile.minimumCount) { $profile.minimumCount } else { "" }
        $maxNodes = if ($profile.maximumCount) { $profile.maximumCount } else { "" }
        Write-Host "     - $profileName`: $profileType (Min: $minNodes, Max: $maxNodes, Cost Weight: $costWeight)" -ForegroundColor Gray
    }
} catch {
    Write-Error "Failed to retrieve workload profiles: $_"
    exit 1
}

# Step 4: Get Container Apps
Write-Host "[4/7] Retrieving Container Apps..." -ForegroundColor Yellow
try {
    $allApps = az containerapp list `
        --resource-group $ResourceGroupName `
        --subscription $SubscriptionId `
        --output json | ConvertFrom-Json
    
    # Filter apps in this environment and using targeted profiles
    $appsInEnv = $allApps | Where-Object { 
        $_.properties.environmentId -eq $environment.id
    }
    
    $appsOnDedicated = $appsInEnv | Where-Object {
        $profileName = $_.properties.workloadProfileName
        $profileName -and ($dedicatedProfiles.name -contains $profileName)
    }
    
    if ($appsOnDedicated.Count -eq 0) {
        Write-Host "" -ForegroundColor Yellow
        Write-Warning "No container apps found running on the targeted workload profiles."
        Write-Host "" -ForegroundColor Yellow
        
        # Check if there are dedicated profiles without apps
        if ($OnlyDedicated -and $dedicatedProfiles.Count -gt 0) {
            Write-Host "⚠️  COST WARNING: Unused Dedicated Workload Profiles" -ForegroundColor Red
            Write-Host "" -ForegroundColor Yellow
            Write-Host "The following dedicated workload profiles are running but have NO applications:" -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Yellow
            
            foreach ($profile in $dedicatedProfiles) {
                $profileType = $profile.workloadProfileType
                $profileName = $profile.name
                $costWeight = Get-ProfileCostWeight -ProfileType $profileType
                
                if ($null -eq $costWeight) {
                    Write-Warning "Unknown workload profile type '$profileType' for profile '$profileName'. Skipping."
                    continue
                }
                
                Write-Host "  \U0001F4CA Profile: $profileName" -ForegroundColor White
                Write-Host "     SKU: $profileType (Cost Weight: $costWeight)" -ForegroundColor Gray
                Write-Host "     Status: Running with 0 applications" -ForegroundColor Red
                Write-Host "     Impact: You are paying for this dedicated profile even though no apps are using it." -ForegroundColor Yellow
                Write-Host "" -ForegroundColor Yellow
            }
            
            Write-Host "💡 Recommendation: Remove unused dedicated workload profiles to reduce costs." -ForegroundColor Cyan
            Write-Host "   Use: az containerapp env workload-profile delete --name <profile-name> --resource-group $ResourceGroupName --environment-name $EnvironmentName" -ForegroundColor Gray
        }
        
        Write-Host "" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "   ✓ Found $($appsOnDedicated.Count) app(s) on dedicated profiles:" -ForegroundColor Green
    foreach ($app in $appsOnDedicated) {
        $profileName = $app.properties.workloadProfileName
        Write-Host "     - $($app.name): Profile=$profileName" -ForegroundColor Gray
    }
} catch {
    Write-Error "Failed to retrieve container apps: $_"
    exit 1
}

# Step 5: Collect Metrics
$appMetrics = @()
$periodHours = ($EndDate - $StartDate).TotalHours

if ($AllocationMode -eq "Reserved") {
    Write-Host "[5/7] Collecting reserved capacity from app configurations..." -ForegroundColor Yellow
    
    foreach ($app in $appsOnDedicated) {
        Write-Host "   Processing: $($app.name)..." -ForegroundColor Gray
        
        $appResourceId = $app.id
        $profileName = $app.properties.workloadProfileName
        
        # Get configured (reserved) resources from app template
        $containers = $app.properties.template.containers
        $configuredCpuCores = 0
        $configuredMemoryGiB = 0
        
        foreach ($container in $containers) {
            # CPU is already in cores
            $configuredCpuCores += [double]$container.resources.cpu
            
            # Memory can be in format "8Gi" or "8"
            $memoryStr = $container.resources.memory
            if ($memoryStr -match '^([\d.]+)Gi$') {
                $configuredMemoryGiB += [double]$Matches[1]
            } elseif ($memoryStr -match '^([\d.]+)$') {
                $configuredMemoryGiB += [double]$Matches[1]
            }
        }
        
        # Get configured replica count from app scale settings (NOT from Azure Monitor)
        $minReplicas = $app.properties.template.scale.minReplicas
        if (-not $minReplicas) { $minReplicas = 0 }
        
        # For Reserved mode, we use minReplicas as the reserved capacity
        # Apps reserve capacity based on their minimum guaranteed replicas
        $configuredReplicas = [int]$minReplicas
        
        # Calculate replica-hours based on configured minReplicas for the full period
        $replicaHours = $configuredReplicas * $periodHours
        
        # Reserved capacity = configured resources × configured minReplicas
        $reservedCpuCores = $configuredCpuCores * $configuredReplicas
        $reservedMemoryGiB = $configuredMemoryGiB * $configuredReplicas
        
        # Store metrics (using reserved capacity)
        $appMetrics += [PSCustomObject]@{
            AppName = $app.name
            WorkloadProfile = $profileName
            ConfiguredCpuCores = $configuredCpuCores
            ConfiguredMemoryGiB = $configuredMemoryGiB
            ConfiguredReplicas = $configuredReplicas
            AvgCpuNanoCores = $reservedCpuCores * 1000000000  # Convert to nanocores for consistency
            AvgCpuCores = $reservedCpuCores
            AvgMemoryBytes = $reservedMemoryGiB * 1073741824  # Convert to bytes for consistency
            AvgMemoryGiB = $reservedMemoryGiB
            AvgReplicas = $configuredReplicas
            ReplicaHours = $replicaHours
            ResourceId = $appResourceId
        }
        
        Write-Host "     ✓ Reserved: $configuredCpuCores cores × $configuredReplicas replicas (min) = $([Math]::Round($reservedCpuCores, 2)) core-replicas, $configuredMemoryGiB GiB × $configuredReplicas replicas = $([Math]::Round($reservedMemoryGiB, 2)) GiB-replicas" -ForegroundColor Gray
    }
    
    Write-Host "   ✓ Reserved capacity collection complete (no Azure Monitor calls)" -ForegroundColor Green
} else {
    # Actual mode - use Azure Monitor metrics
    Write-Host "[5/7] Collecting actual usage metrics from Azure Monitor..." -ForegroundColor Yellow
    Write-Host "   This may take a few minutes..." -ForegroundColor Gray
    
    foreach ($app in $appsOnDedicated) {
        Write-Host "   Processing: $($app.name)..." -ForegroundColor Gray
        
        $appResourceId = $app.id
        $profileName = $app.properties.workloadProfileName
        
        # Get CPU metrics
        $cpuMetrics = Get-ACAMetrics `
            -ResourceId $appResourceId `
            -MetricName "UsageNanoCores" `
            -StartTime $StartDate `
            -EndTime $EndDate `
            -Aggregation "Average"
        
        # Get Memory metrics
        $memoryMetrics = Get-ACAMetrics `
            -ResourceId $appResourceId `
            -MetricName "WorkingSetBytes" `
            -StartTime $StartDate `
            -EndTime $EndDate `
            -Aggregation "Average"
        
        # Get Replica count metrics
        $replicaMetrics = Get-ACAMetrics `
            -ResourceId $appResourceId `
            -MetricName "Replicas" `
            -StartTime $StartDate `
            -EndTime $EndDate `
            -Aggregation "Average"
        
        # Calculate totals
        $avgCpuNanoCores = ($cpuMetrics | Measure-Object -Property value -Average).Average
        if (-not $avgCpuNanoCores) { $avgCpuNanoCores = 0 }
        
        $avgMemoryBytes = ($memoryMetrics | Measure-Object -Property value -Average).Average
        if (-not $avgMemoryBytes) { $avgMemoryBytes = 0 }
        
        $avgReplicas = ($replicaMetrics | Measure-Object -Property value -Average).Average
        if (-not $avgReplicas) { $avgReplicas = 0 }
        
        # Calculate replica-hours
        $replicaHours = $avgReplicas * $periodHours
        
        # Store metrics
        $appMetrics += [PSCustomObject]@{
            AppName = $app.name
            WorkloadProfile = $profileName
            AvgCpuNanoCores = $avgCpuNanoCores
            AvgCpuCores = $avgCpuNanoCores / 1000000000
            AvgMemoryBytes = $avgMemoryBytes
            AvgMemoryGiB = $avgMemoryBytes / 1073741824
            AvgReplicas = $avgReplicas
            ReplicaHours = $replicaHours
            ResourceId = $appResourceId
        }
        
        Write-Host "     ✓ Actual: $([Math]::Round($avgCpuNanoCores / 1000000000, 3)) cores, $([Math]::Round($avgMemoryBytes / 1073741824, 2)) GiB, $([Math]::Round($avgReplicas, 2)) replicas" -ForegroundColor Gray
    }
    
    Write-Host "   ✓ Actual usage metrics collection complete" -ForegroundColor Green
}

# Step 6: Calculate Cost Allocation
Write-Host "[6/7] Calculating cost allocation..." -ForegroundColor Yellow

# Calculate totals per workload profile
$profileTotals = @{}
$profileCostWeights = @{}

foreach ($profile in $dedicatedProfiles) {
    $appsOnProfile = $appMetrics | Where-Object { $_.WorkloadProfile -eq $profile.name }
    
    $totalCpu = ($appsOnProfile | Measure-Object -Property AvgCpuNanoCores -Sum).Sum
    $totalMemory = ($appsOnProfile | Measure-Object -Property AvgMemoryBytes -Sum).Sum
    $totalReplicaHours = ($appsOnProfile | Measure-Object -Property ReplicaHours -Sum).Sum
    
    # Get cost weight for this profile type
    $costWeight = Get-ProfileCostWeight -ProfileType $profile.workloadProfileType
    if ($null -eq $costWeight) {
        Write-Warning "Unknown workload profile type: $($profile.workloadProfileType) for profile $($profile.name). Skipping."
        continue
    }
    
    $profileTotals[$profile.name] = @{
        TotalCpu = $totalCpu
        TotalMemory = $totalMemory
        TotalReplicaHours = $totalReplicaHours
    }
    
    $profileCostWeights[$profile.name] = $costWeight
}

# Calculate percentage allocation for each app using 3-step model:
# Step 1: Calculate resource cost share (CPU% × 0.92 + Memory% × 0.08)
# Step 2: Scale by replica time usage (multiply by replica time %)
# Step 3: Normalize to 100%

$results = @()
$profileFinalCostShares = @{}  # Track totals for normalization

# First pass: Calculate resource cost share and final cost share for each app
foreach ($app in $appMetrics) {
    $totals = $profileTotals[$app.WorkloadProfile]
    
    # Calculate individual percentages within this profile
    $cpuPercent = if ($totals.TotalCpu -gt 0) { ($app.AvgCpuNanoCores / $totals.TotalCpu) * 100 } else { 0 }
    $memoryPercent = if ($totals.TotalMemory -gt 0) { ($app.AvgMemoryBytes / $totals.TotalMemory) * 100 } else { 0 }
    $replicaPercent = if ($totals.TotalReplicaHours -gt 0) { ($app.ReplicaHours / $totals.TotalReplicaHours) * 100 } else { 0 }
    
    # Step 1: Calculate resource cost share (weighted by pricing: CPU=$0.0571, Memory=$0.0050)
    $resourceCostShare = ($cpuPercent * $CpuWeight) + ($memoryPercent * $MemoryWeight)
    
    # Step 2: Scale by replica time usage (replica time as multiplier)
    $finalCostShare = $resourceCostShare * ($replicaPercent / 100)
    
    # Track total for this profile for normalization
    if (-not $profileFinalCostShares.ContainsKey($app.WorkloadProfile)) {
        $profileFinalCostShares[$app.WorkloadProfile] = 0
    }
    $profileFinalCostShares[$app.WorkloadProfile] += $finalCostShare
    
    $results += [PSCustomObject]@{
        AppName = $app.AppName
        WorkloadProfile = $app.WorkloadProfile
        ProfileCostWeight = $profileCostWeights[$app.WorkloadProfile]
        AvgCpuCores = [Math]::Round($app.AvgCpuCores, 3)
        AvgMemoryGiB = [Math]::Round($app.AvgMemoryGiB, 2)
        AvgReplicas = [Math]::Round($app.AvgReplicas, 2)
        ReplicaHours = [Math]::Round($app.ReplicaHours, 2)
        CpuUsagePercent = [Math]::Round($cpuPercent, 2)
        MemoryUsagePercent = [Math]::Round($memoryPercent, 2)
        ReplicaTimePercent = [Math]::Round($replicaPercent, 2)
        ResourceCostShare = [Math]::Round($resourceCostShare, 2)
        FinalCostShare = [Math]::Round($finalCostShare, 4)
        ProfileAllocationPercent = 0  # Will be calculated in Step 3
    }
}

# Step 3: Normalize to 100% within each profile
foreach ($app in $results) {
    $totalShare = $profileFinalCostShares[$app.WorkloadProfile]
    if ($totalShare -gt 0) {
        $app.ProfileAllocationPercent = [Math]::Round(($app.FinalCostShare / $totalShare) * 100, 2)
    } else {
        $app.ProfileAllocationPercent = 0
    }
}

# Calculate environment-wide allocation (normalized by profile cost weights)
$totalWeightedCost = 0
foreach ($app in $results) {
    $app | Add-Member -NotePropertyName "WeightedCost" -NotePropertyValue ($app.ProfileAllocationPercent * $app.ProfileCostWeight / 100)
    $totalWeightedCost += $app.WeightedCost
}

# Add environment-wide percentage
foreach ($app in $results) {
    $envWidePercent = if ($totalWeightedCost -gt 0) { ($app.WeightedCost / $totalWeightedCost) * 100 } else { 0 }
    $app | Add-Member -NotePropertyName "EnvironmentCostPercent" -NotePropertyValue ([Math]::Round($envWidePercent, 2))
}

Write-Host "   ✓ Cost allocation calculated" -ForegroundColor Green

# Step 7: Output Results
Write-Host "[7/7] Generating report..." -ForegroundColor Yellow

# Display summary
Write-Host ""
Write-Host "===== COST ALLOCATION RESULTS ($AllocationMode Mode) =====" -ForegroundColor Cyan
Write-Host ""

$cpuLabel = if ($AllocationMode -eq 'Reserved') { 'Reserved CPU' } else { 'Actual CPU' }
$memLabel = if ($AllocationMode -eq 'Reserved') { 'Reserved Memory' } else { 'Actual Memory' }

# Show per-profile breakdown
foreach ($profile in $dedicatedProfiles) {
    $appsOnProfile = $results | Where-Object { $_.WorkloadProfile -eq $profile.name }
    
    if ($appsOnProfile.Count -gt 0) {
        $profileCostWeight = $profileCostWeights[$profile.name]
        
        Write-Host "Workload Profile: $($profile.name) ($($profile.workloadProfileType), Cost Weight: $profileCostWeight)" -ForegroundColor Yellow
        Write-Host ""
        
        $appsOnProfile | Sort-Object ProfileAllocationPercent -Descending | ForEach-Object {
            Write-Host "  $($_.AppName)" -ForegroundColor White
            Write-Host "    Profile Allocation: $($_.ProfileAllocationPercent)%" -ForegroundColor Cyan
            Write-Host "    Environment-Wide Cost: $($_.EnvironmentCostPercent)%" -ForegroundColor Green
            Write-Host "    - $cpuLabel`: $($_.CpuUsagePercent)% ($($_.AvgCpuCores) cores)" -ForegroundColor Gray
            Write-Host "    - $memLabel`: $($_.MemoryUsagePercent)% ($($_.AvgMemoryGiB) GiB)" -ForegroundColor Gray
            Write-Host "    - Replica Time: $($_.ReplicaTimePercent)% ($($_.ReplicaHours) replica-hours)" -ForegroundColor Gray
            Write-Host ""
        }
        
        $totalProfileAllocation = ($appsOnProfile | Measure-Object -Property ProfileAllocationPercent -Sum).Sum
        $totalEnvAllocation = ($appsOnProfile | Measure-Object -Property EnvironmentCostPercent -Sum).Sum
        Write-Host "  Profile Total: $([Math]::Round($totalProfileAllocation, 2))% | Environment Total: $([Math]::Round($totalEnvAllocation, 2))%" -ForegroundColor Green
        Write-Host ""
    }
}

# Show environment-wide summary
if ($dedicatedProfiles.Count -gt 1) {
    Write-Host "===== ENVIRONMENT-WIDE SUMMARY =====" -ForegroundColor Cyan
    Write-Host ""
    $results | Sort-Object EnvironmentCostPercent -Descending | ForEach-Object {
        Write-Host "  $($_.AppName) ($($_.WorkloadProfile)): $($_.EnvironmentCostPercent)%" -ForegroundColor White
    }
    $totalEnvCost = ($results | Measure-Object -Property EnvironmentCostPercent -Sum).Sum
    Write-Host ""
    Write-Host "  Total Environment Cost: $([Math]::Round($totalEnvCost, 2))%" -ForegroundColor Green
    Write-Host ""
}

# Export to CSV
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $OutputPath "ACA-CostBreakdown-$EnvironmentName-$timestamp.csv"

try {
    $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "✓ Results exported to: $outputFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to export CSV: $_"
}

# Validation check
Write-Host ""
Write-Host "===== VALIDATION =====" -ForegroundColor Cyan

# Validate per-profile allocations
foreach ($profile in $dedicatedProfiles) {
    $appsOnProfile = $results | Where-Object { $_.WorkloadProfile -eq $profile.name }
    if ($appsOnProfile.Count -gt 0) {
        $totalAllocation = ($appsOnProfile | Measure-Object -Property ProfileAllocationPercent -Sum).Sum
        $status = if ([Math]::Abs($totalAllocation - 100) -lt 0.1) { "✓" } else { "⚠" }
        Write-Host "$status Profile '$($profile.name)' allocation: $([Math]::Round($totalAllocation, 2))%" -ForegroundColor $(if ($status -eq "✓") { "Green" } else { "Yellow" })
    }
}

# Validate environment-wide allocation
$totalEnvAllocation = ($results | Measure-Object -Property EnvironmentCostPercent -Sum).Sum
$envStatus = if ([Math]::Abs($totalEnvAllocation - 100) -lt 0.1) { "✓" } else { "⚠" }
Write-Host "$envStatus Environment-wide total allocation: $([Math]::Round($totalEnvAllocation, 2))%" -ForegroundColor $(if ($envStatus -eq "✓") { "Green" } else { "Yellow" })

Write-Host ""
Write-Host "Analysis complete!" -ForegroundColor Green
