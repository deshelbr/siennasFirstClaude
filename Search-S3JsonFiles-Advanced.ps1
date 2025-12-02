#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Advanced S3 JSON search using S3 Select for server-side filtering.

.DESCRIPTION
    Uses AWS S3 Select to perform server-side searches, dramatically reducing
    data transfer and search time for large datasets. Falls back to download
    method if S3 Select is not available or fails.

.PARAMETER BucketName
    The name of the S3 bucket

.PARAMETER Prefix
    The S3 prefix (directory path) to search within

.PARAMETER SearchString
    The string to search for in JSON file contents

.PARAMETER TargetDate
    Filter files created on this date (format: yyyy-MM-dd)

.PARAMETER JsonPath
    Optional: JSON path to search within (e.g., "s.errorMessage" for nested field)

.PARAMETER Region
    AWS Region (defaults to us-west-1)

.PARAMETER UseS3Select
    Use S3 Select for server-side filtering (much faster, default: $true)

.EXAMPLE
    .\Search-S3JsonFiles-Advanced.ps1 -BucketName "my-bucket" -Prefix "data/" -SearchString "error123" -TargetDate "2025-10-18"

.EXAMPLE
    # Search in a specific JSON field
    .\Search-S3JsonFiles-Advanced.ps1 -BucketName "my-bucket" -Prefix "data/" -SearchString "error123" -TargetDate "2025-10-18" -JsonPath "s.logs"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$BucketName,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$Prefix,

    [Parameter(Mandatory=$true, Position=2)]
    [string]$SearchString,

    [Parameter(Mandatory=$true, Position=3)]
    [string]$TargetDate,

    [Parameter(Mandatory=$false)]
    [string]$JsonPath,

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-west-1",

    [Parameter(Mandatory=$false)]
    [switch]$UseS3Select,

    [Parameter(Mandatory=$false)]
    [int]$MaxParallel = 20
)

$ErrorActionPreference = "Stop"

# Parse target date
$targetDateTime = [DateTime]::ParseExact($TargetDate, "yyyy-MM-dd", $null)
$startOfDay = $targetDateTime.Date
$endOfDay = $startOfDay.AddDays(1).AddSeconds(-1)

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Advanced S3 JSON Search Tool" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Bucket: $BucketName" -ForegroundColor White
Write-Host "Prefix: $Prefix" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "Search String: $SearchString" -ForegroundColor White
Write-Host "Target Date: $TargetDate" -ForegroundColor White
Write-Host "S3 Select: $UseS3Select" -ForegroundColor White
if ($JsonPath) {
    Write-Host "JSON Path: $JsonPath" -ForegroundColor White
}
Write-Host ""

# Step 1: List and filter by date
Write-Host "[1/3] Filtering S3 objects by date..." -ForegroundColor Yellow

$filteredKeys = @()
$totalObjects = 0
$continuationToken = $null

do {
    $listParams = @{
        BucketName = $BucketName
        Prefix = $Prefix
        Region = $Region
        MaxKeys = 1000
    }
    
    if ($continuationToken) {
        $listParams['ContinuationToken'] = $continuationToken
    }
    
    try {
        $objects = Get-S3Object @listParams

        foreach ($obj in $objects) {
            $totalObjects++

            if ($obj.LastModified -ge $startOfDay -and $obj.LastModified -le $endOfDay) {
                if ($obj.Key -match '\.json$') {
                    $filteredKeys += [PSCustomObject]@{
                        Key = $obj.Key
                        Size = $obj.Size
                        LastModified = $obj.LastModified
                    }
                }
            }
        }

        $continuationToken = $objects.NextContinuationToken
        
        if ($totalObjects % 5000 -eq 0) {
            Write-Host "  Scanned $totalObjects objects, found $($filteredKeys.Count) on target date..." -ForegroundColor Gray
        }
        
    } catch {
        Write-Error "Error listing objects: $_"
        exit 1
    }
    
} while ($continuationToken)

Write-Host "  Total objects scanned: $totalObjects" -ForegroundColor Green
Write-Host "  Files matching date: $($filteredKeys.Count)" -ForegroundColor Green
Write-Host ""

if ($filteredKeys.Count -eq 0) {
    Write-Host "No JSON files found for the specified date." -ForegroundColor Red
    exit 0
}

# Step 2: Search using S3 Select or download method
Write-Host "[2/3] Searching file contents..." -ForegroundColor Yellow

$matchingFiles = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()
$failedS3Select = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

# Process files in parallel
$processed = 0

$filteredKeys | ForEach-Object -Parallel {
    # Import AWS module in parallel context
    Import-Module AWS.Tools.S3 -ErrorAction SilentlyContinue

    $fileObj = $_
    $bucket = $using:BucketName
    $region = $using:Region
    $search = $using:SearchString
    $jsonPath = $using:JsonPath
    $useSelect = $using:UseS3Select
    $matches = $using:matchingFiles
    $failed = $using:failedS3Select

    $found = $false

    # Try S3 Select first if enabled
    if ($useSelect) {
        try {
            # Build S3 Select query
            if ($jsonPath) {
                $expression = "SELECT * FROM S3Object[*] s WHERE $jsonPath LIKE '%$search%'"
            } else {
                $expression = "SELECT * FROM S3Object[*] s"
            }

            $selectParams = @{
                BucketName = $bucket
                Key = $fileObj.Key
                Expression = $expression
                ExpressionType = 'SQL'
                InputSerialization_JSON_Type = 'DOCUMENT'
                InputSerialization_CompressionType = 'NONE'
                OutputSerialization_JSON_RecordDelimiter = "`n"
            }

            $result = Select-S3ObjectContent @selectParams

            if ($result -and $result.Payload) {
                $found = $true
            }
        } catch {
            # S3 Select failed, fall back to download
            $failed.Add($fileObj.Key)
            $found = $null
        }
    }

    # Fall back to download if S3 Select not used or failed
    if ($null -eq $found) {
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Read-S3Object -BucketName $bucket -Key $fileObj.Key -File $tempFile > $null
            $content = Get-Content -Path $tempFile -Raw
            $found = $content.Contains($search)
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Error processing $($fileObj.Key): $_"
            $found = $false
        }
    }

    if ($found) {
        $matches.Add([PSCustomObject]@{
            Key = $fileObj.Key
            Size = $fileObj.Size
            LastModified = $fileObj.LastModified
        })
    }

    # Progress update
    $script:processed++
    if ($script:processed % 100 -eq 0) {
        Write-Host "    Processed $($script:processed) / $($using:filteredKeys.Count) files..." -ForegroundColor Gray
    }

} -ThrottleLimit $MaxParallel

Write-Host "  Completed searching $($filteredKeys.Count) files" -ForegroundColor Green

if ($failedS3Select.Count -gt 0) {
    Write-Host "  Note: $($failedS3Select.Count) files required download fallback" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Display results
Write-Host "[3/3] Results:" -ForegroundColor Yellow
Write-Host ""

if ($matchingFiles.Count -eq 0) {
    Write-Host "No files found containing '$SearchString'" -ForegroundColor Red
} else {
    Write-Host "Found $($matchingFiles.Count) matching file(s):" -ForegroundColor Green
    Write-Host ""
    
    foreach ($file in $matchingFiles | Sort-Object -Property LastModified) {
        Write-Host "  • $($file.Key)" -ForegroundColor Cyan
        Write-Host "    Modified: $($file.LastModified)" -ForegroundColor Gray
        Write-Host "    Size: $([Math]::Round($file.Size / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Export results
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvFile = "search_results_$timestamp.csv"
    $matchingFiles | Export-Csv -Path $csvFile -NoTypeInformation
    
    Write-Host "Results exported to: $csvFile" -ForegroundColor Green
    Write-Host ""
    
    # Show download commands for easy retrieval
    Write-Host "To download matching files:" -ForegroundColor Yellow
    foreach ($file in $matchingFiles) {
        $filename = Split-Path $file.Key -Leaf
        Write-Host "  aws s3 cp s3://$BucketName/$($file.Key) ./$filename --region $Region" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Search Complete" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
