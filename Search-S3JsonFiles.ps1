#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Searches S3 bucket JSON files for a specific string, with date filtering.

.DESCRIPTION
    Efficiently searches through large numbers of JSON files in an S3 bucket
    by first filtering by creation date, then searching content in parallel.

.PARAMETER BucketName
    The name of the S3 bucket

.PARAMETER Prefix
    The S3 prefix (directory path) to search within

.PARAMETER SearchString
    The string to search for in JSON file contents

.PARAMETER TargetDate
    Filter files created on this date (format: yyyy-MM-dd)

.PARAMETER Region
    AWS Region (defaults to us-west-1)

.PARAMETER MaxParallel
    Maximum number of parallel downloads (default: 10)

.EXAMPLE
    .\Search-S3JsonFiles.ps1 -BucketName "my-bucket" -Prefix "data/" -SearchString "error123" -TargetDate "2025-10-18"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$true)]
    [string]$Prefix,
    
    [Parameter(Mandatory=$true)]
    [string]$SearchString,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetDate,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-west-1",
    
    [Parameter(Mandatory=$false)]
    [int]$MaxParallel = 10
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion.Major
if ($psVersion -lt 5) {
    Write-Error "This script requires PowerShell 5.1 or later. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

$useParallel = $psVersion -ge 7

if (-not $useParallel) {
    Write-Host "Note: Using PowerShell $psVersion - parallel processing disabled. For faster searches, use PowerShell 7+ (pwsh)" -ForegroundColor Yellow
    Write-Host ""
}

# Parse target date
$targetDateTime = [DateTime]::ParseExact($TargetDate, "yyyy-MM-dd", $null)
$startOfDay = $targetDateTime.Date
$endOfDay = $startOfDay.AddDays(1).AddSeconds(-1)

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "S3 JSON File Search Tool" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Bucket: $BucketName" -ForegroundColor White
Write-Host "Prefix: $Prefix" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "Search String: $SearchString" -ForegroundColor White
Write-Host "Target Date: $TargetDate" -ForegroundColor White
Write-Host ""

# Step 1: List all objects and filter by date
Write-Host "[1/3] Listing S3 objects and filtering by date..." -ForegroundColor Yellow

$filteredKeys = @()
$totalObjects = 0
$nextToken = $null

do {
    $params = @{
        BucketName = $BucketName
        Prefix = $Prefix
        Region = $Region
    }
    
    if ($nextToken) {
        $params['ContinuationToken'] = $nextToken
    }
    
    $response = Get-S3Object @params
    
    foreach ($obj in $response) {
        $totalObjects++
        
        # Filter by date
        if ($obj.LastModified -ge $startOfDay -and $obj.LastModified -le $endOfDay) {
            # Only include .json files
            if ($obj.Key -match '\.json$') {
                $filteredKeys += $obj.Key
            }
        }
    }
    
    $nextToken = $response.NextContinuationToken
    
    Write-Host "  Processed $totalObjects objects, found $($filteredKeys.Count) matching date filter..." -ForegroundColor Gray
    
} while ($nextToken)

Write-Host "  Total objects scanned: $totalObjects" -ForegroundColor Green
Write-Host "  Files matching date ($TargetDate): $($filteredKeys.Count)" -ForegroundColor Green
Write-Host ""

if ($filteredKeys.Count -eq 0) {
    Write-Host "No JSON files found for the specified date." -ForegroundColor Red
    exit 0
}

# Step 2: Search through filtered files
if ($useParallel) {
    Write-Host "[2/3] Searching file contents in parallel (max $MaxParallel threads)..." -ForegroundColor Yellow
} else {
    Write-Host "[2/3] Searching file contents sequentially..." -ForegroundColor Yellow
}

$matchingFiles = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()
$processed = 0

if ($useParallel) {
    # PowerShell 7+ parallel processing
    $filteredKeys | ForEach-Object -Parallel {
        # Import AWS module in parallel context
        Import-Module AWS.Tools.S3 -ErrorAction SilentlyContinue

        $key = $_
        $bucket = $using:BucketName
        $search = $using:SearchString
        $bag = $using:matchingFiles

        try {
            # Download file content to temp location
            $tempFile = [System.IO.Path]::GetTempFileName()
            $null = Read-S3Object -BucketName $bucket -Key $key -File $tempFile

            # Read content
            $content = Get-Content -Path $tempFile -Raw -ErrorAction SilentlyContinue

            # Search for string
            if ($content -and $content.Contains($search)) {
                $result = [PSCustomObject]@{
                    Key = $key
                    Size = (Get-Item $tempFile).Length
                    Found = $true
                }
                $bag.Add($result)
            }

            # Clean up temp file
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }

            # Update progress
            $script:processed++
            if ($script:processed % 50 -eq 0) {
                Write-Host "    Processed $($script:processed) / $($using:filteredKeys.Count) files..." -ForegroundColor Gray
            }

        } catch {
            Write-Warning "Error processing $key : $_"
        }
    } -ThrottleLimit $MaxParallel
} else {
    # PowerShell 5.1 sequential processing
    foreach ($key in $filteredKeys) {
        try {
            # Download file content to temp location
            $tempFile = [System.IO.Path]::GetTempFileName()
            $null = Read-S3Object -BucketName $BucketName -Key $key -File $tempFile

            # Read content
            $content = Get-Content -Path $tempFile -Raw -ErrorAction SilentlyContinue

            # Search for string
            if ($content -and $content.Contains($SearchString)) {
                $result = [PSCustomObject]@{
                    Key = $key
                    Size = (Get-Item $tempFile).Length
                    Found = $true
                }
                $matchingFiles.Add($result)
            }

            # Clean up temp file
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }

            # Update progress
            $processed++
            if ($processed % 50 -eq 0) {
                Write-Host "    Processed $processed / $($filteredKeys.Count) files..." -ForegroundColor Gray
            }

        } catch {
            Write-Warning "Error processing $key : $_"
        }
    }
}

Write-Host "  Completed searching $($filteredKeys.Count) files" -ForegroundColor Green
Write-Host ""

# Step 3: Display results
Write-Host "[3/3] Results:" -ForegroundColor Yellow
Write-Host ""

if ($matchingFiles.Count -eq 0) {
    Write-Host "No files found containing the search string '$SearchString'" -ForegroundColor Red
} else {
    Write-Host "Found $($matchingFiles.Count) file(s) containing '$SearchString':" -ForegroundColor Green
    Write-Host ""
    
    foreach ($file in $matchingFiles) {
        Write-Host "  • $($file.Key)" -ForegroundColor Cyan
        Write-Host "    Size: $([Math]::Round($file.Size / 1KB, 2)) KB" -ForegroundColor Gray
    }
    
    # Export results to CSV
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputFile = "search_results_$timestamp.csv"
    $matchingFiles | Export-Csv -Path $outputFile -NoTypeInformation
    
    Write-Host ""
    Write-Host "Results exported to: $outputFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Search Complete" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
