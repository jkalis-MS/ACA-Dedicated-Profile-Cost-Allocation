<#
.SYNOPSIS
    Helper functions for Azure Container Apps metrics collection
#>

function Get-ACAMetrics {
    <#
    .SYNOPSIS
        Retrieves metrics from Azure Monitor for a Container App
        
    .PARAMETER ResourceId
        Full resource ID of the Container App
        
    .PARAMETER MetricName
        Name of the metric to retrieve (e.g., UsageNanoCores, WorkingSetBytes, Replicas)
        
    .PARAMETER StartTime
        Start time for metrics query
        
    .PARAMETER EndTime
        End time for metrics query
        
    .PARAMETER Aggregation
        Aggregation type (Average, Minimum, Maximum, Total)
        
    .PARAMETER Interval
        Time grain for aggregation (default: PT1H for 1 hour)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceId,
        
        [Parameter(Mandatory = $true)]
        [string]$MetricName,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$StartTime,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$EndTime,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Average", "Minimum", "Maximum", "Total", "Count")]
        [string]$Aggregation = "Average",
        
        [Parameter(Mandatory = $false)]
        [string]$Interval = "PT1H"
    )
    
    try {
        # Format dates for Azure Monitor API (ISO 8601)
        $startTimeStr = $StartTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTimeStr = $EndTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        # Get access token for Azure Management API
        # Try Azure CLI first, fall back to Az PowerShell
        try {
            $tokenInfo = az account get-access-token --resource https://management.azure.com 2>$null | ConvertFrom-Json
            $token = $tokenInfo.accessToken
        } catch {
            $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
        }
        
        # Build API URL
        $apiVersion = "2023-10-01"
        $baseUrl = "https://management.azure.com"
        $metricsUrl = "$baseUrl$ResourceId/providers/Microsoft.Insights/metrics"
        
        $queryParams = @(
            "api-version=$apiVersion"
            "metricnames=$MetricName"
            "timespan=$startTimeStr/$endTimeStr"
            "interval=$Interval"
            "aggregation=$Aggregation"
        )
        
        $url = "$metricsUrl`?$($queryParams -join '&')"
        
        # Make API request
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        
        # Extract metric values
        $metricData = @()
        
        if ($response.value -and $response.value.Count -gt 0) {
            $metric = $response.value[0]
            
            foreach ($timeseries in $metric.timeseries) {
                foreach ($dataPoint in $timeseries.data) {
                    if ($dataPoint.$Aggregation -ne $null) {
                        $metricData += [PSCustomObject]@{
                            timestamp = $dataPoint.timeStamp
                            value = $dataPoint.$Aggregation
                        }
                    }
                }
            }
        }
        
        return $metricData
        
    } catch {
        Write-Warning "Failed to retrieve metrics for $MetricName from $ResourceId : $_"
        return @()
    }
}

function Get-WorkloadProfileCost {
    <#
    .SYNOPSIS
        Retrieves cost data for a workload profile from Azure Cost Management API
        
    .PARAMETER SubscriptionId
        Azure Subscription ID
        
    .PARAMETER ResourceGroupName
        Resource Group name
        
    .PARAMETER WorkloadProfileName
        Name of the workload profile
        
    .PARAMETER StartDate
        Start date for cost query
        
    .PARAMETER EndDate
        End date for cost query
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$WorkloadProfileName,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$StartDate,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$EndDate
    )
    
    try {
        # Note: Azure Cost Management API has 8-24 hour delay
        # This is a placeholder for future cost integration
        
        Write-Warning "Cost Management API integration not yet implemented. Cost data would be retrieved from Azure Cost Management."
        Write-Host "   For now, you can manually retrieve costs from Azure Portal > Cost Management + Billing" -ForegroundColor Gray
        Write-Host "   Filter by: Resource Group = $ResourceGroupName, Resource Type = Microsoft.App/managedEnvironments" -ForegroundColor Gray
        
        return $null
        
    } catch {
        Write-Warning "Failed to retrieve cost data: $_"
        return $null
    }
}

function Format-MetricValue {
    <#
    .SYNOPSIS
        Formats metric values for display
        
    .PARAMETER Value
        Numeric value to format
        
    .PARAMETER Unit
        Unit type (bytes, cores, etc.)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$Value,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("bytes", "cores", "nanocores", "count")]
        [string]$Unit = "count"
    )
    
    switch ($Unit) {
        "bytes" {
            if ($Value -gt 1TB) {
                return "$([Math]::Round($Value / 1TB, 2)) TB"
            } elseif ($Value -gt 1GB) {
                return "$([Math]::Round($Value / 1GB, 2)) GB"
            } elseif ($Value -gt 1MB) {
                return "$([Math]::Round($Value / 1MB, 2)) MB"
            } else {
                return "$([Math]::Round($Value / 1KB, 2)) KB"
            }
        }
        "nanocores" {
            return "$([Math]::Round($Value / 1000000000, 3)) cores"
        }
        "cores" {
            return "$([Math]::Round($Value, 3)) cores"
        }
        default {
            return "$([Math]::Round($Value, 2))"
        }
    }
}

function Test-AzureConnection {
    <#
    .SYNOPSIS
        Tests if Azure PowerShell is connected and has required modules
    #>
    [CmdletBinding()]
    param()
    
    # Check if Az.Accounts module is available
    if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Write-Error "Az.Accounts module not found. Please install: Install-Module -Name Az.Accounts"
        return $false
    }
    
    # Check if logged in
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not logged in to Azure. Please run: Connect-AzAccount"
        return $false
    }
    
    # Check if Azure CLI is available
    try {
        $cliVersion = az version --output json 2>$null | ConvertFrom-Json
        if (-not $cliVersion) {
            Write-Warning "Azure CLI not found or not in PATH. Some features may not work."
            Write-Warning "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        }
    } catch {
        Write-Warning "Azure CLI not found. Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    }
    
    return $true
}

# Functions are available when dot-sourced - no Export-ModuleMember needed
