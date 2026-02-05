#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnostic tool to check LastModified dates of S3 files

.DESCRIPTION
    Lists files in S3 bucket with their LastModified timestamps to help
    troubleshoot date filtering issues

.PARAMETER BucketName
    The S3 bucket name

.PARAMETER Prefix
    The S3 prefix (folder path)

.PARAMETER Region
    AWS region (default: us-east-1)

.PARAMETER MaxFiles
    Maximum number of files to display (default: 50)

.EXAMPLE
    ./Diagnose-S3Files.ps1 -BucketName "my-bucket" -Prefix "data/2025/"

.EXAMPLE
    ./Diagnose-S3Files.ps1 -BucketName "my-bucket" -Prefix "data/" -Region "us-west-2" -MaxFiles 100
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,

    [Parameter(Mandatory=$false)]
    [string]$Prefix = "",

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",

    [Parameter(Mandatory=$false)]
    [int]$MaxFiles = 50
)

$ErrorActionPreference = "Stop"

# Import AWS module
Import-Module AWS.Tools.S3 -Force -ErrorAction Stop

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "S3 File Date Diagnostic Tool" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Bucket: $BucketName" -ForegroundColor White
Write-Host "Prefix: $Prefix" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host ""

Write-Host "Listing files and their LastModified dates..." -ForegroundColor Yellow
Write-Host ""

try {
    $allObjects = @()
    $jsonObjects = @()
    $continuationToken = $null
    $totalCount = 0
    $jsonCount = 0

    do {
        $params = @{
            BucketName = $BucketName
            Prefix = $Prefix
            Region = $Region
        }

        if ($continuationToken) {
            $params['ContinuationToken'] = $continuationToken
        }

        $response = Get-S3Object @params

        if ($response) {
            foreach ($obj in $response) {
                $totalCount++
                $isJson = $obj.Key -match '\.json$'

                if ($isJson) {
                    $jsonCount++
                }

                # Display first MaxFiles (all file types)
                if ($totalCount -le $MaxFiles) {
                    $localTime = $obj.LastModified.ToLocalTime()
                    $utcTime = $obj.LastModified.ToUniversalTime()

                    $typeIndicator = if ($isJson) { "[JSON]" } else { "[OTHER]" }
                    $color = if ($isJson) { "Cyan" } else { "Gray" }

                    Write-Host "$typeIndicator File: $($obj.Key)" -ForegroundColor $color
                    Write-Host "  Size: $([Math]::Round($obj.Size / 1KB, 2)) KB" -ForegroundColor Gray
                    Write-Host "  LastModified (UTC): $($utcTime.ToString('yyyy-MM-dd HH:mm:ss'))  [Date: $($utcTime.ToString('yyyy-MM-dd'))]" -ForegroundColor Yellow
                    Write-Host "  LastModified (Local): $($localTime.ToString('yyyy-MM-dd HH:mm:ss'))  [Date: $($localTime.ToString('yyyy-MM-dd'))]" -ForegroundColor Green
                    Write-Host ""
                }

                $allObjects += [PSCustomObject]@{
                    Key = $obj.Key
                    Size = $obj.Size
                    IsJSON = $isJson
                    LastModifiedUTC = $obj.LastModified.ToUniversalTime()
                    LastModifiedLocal = $obj.LastModified.ToLocalTime()
                    DateUTC = $obj.LastModified.ToUniversalTime().ToString('yyyy-MM-dd')
                    DateLocal = $obj.LastModified.ToLocalTime().ToString('yyyy-MM-dd')
                }

                if ($isJson) {
                    $jsonObjects += $allObjects[-1]
                }
            }

            $continuationToken = $response.NextContinuationToken
        }
    } while ($continuationToken)

    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "Summary" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "Total files found: $totalCount" -ForegroundColor White
    Write-Host "JSON files (.json): $jsonCount" -ForegroundColor Cyan
    Write-Host "Other files: $($totalCount - $jsonCount)" -ForegroundColor Gray

    if ($totalCount -gt $MaxFiles) {
        Write-Host "(Only showing first $MaxFiles files above)" -ForegroundColor Gray
    }

    if ($totalCount -eq 0) {
        Write-Host ""
        Write-Host "WARNING: No files found!" -ForegroundColor Red
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "  1. The prefix might be incorrect (try without prefix or different path)" -ForegroundColor White
        Write-Host "  2. The bucket might be empty at this prefix" -ForegroundColor White
        Write-Host "  3. Prefix should NOT start with '/' - use 'folder/subfolder/' instead" -ForegroundColor White
        Write-Host ""
    }

    if ($jsonCount -gt 0) {
        Write-Host ""
        Write-Host "Unique dates in LastModified (UTC) for JSON files:" -ForegroundColor Yellow
        $uniqueDatesUTC = $jsonObjects | Select-Object -ExpandProperty DateUTC | Sort-Object -Unique
        foreach ($date in $uniqueDatesUTC) {
            $count = ($jsonObjects | Where-Object { $_.DateUTC -eq $date }).Count
            Write-Host "  $date : $count files" -ForegroundColor Cyan
        }

        Write-Host ""
        Write-Host "Unique dates in LastModified (Local) for JSON files:" -ForegroundColor Green
        $uniqueDatesLocal = $jsonObjects | Select-Object -ExpandProperty DateLocal | Sort-Object -Unique
        foreach ($date in $uniqueDatesLocal) {
            $count = ($jsonObjects | Where-Object { $_.DateLocal -eq $date }).Count
            Write-Host "  $date : $count files" -ForegroundColor Cyan
        }
    }

    Write-Host ""
    Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
    Write-Host "1. The search scripts use UTC dates for filtering" -ForegroundColor White
    Write-Host "2. Use one of the UTC dates listed above as your -TargetDate parameter" -ForegroundColor White
    Write-Host "3. Format: yyyy-MM-dd (e.g., 2025-02-05)" -ForegroundColor White
    Write-Host ""

    # Export to CSV
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvPath = "file_dates_diagnostic_$timestamp.csv"
    $allObjects | Export-Csv -Path $csvPath -NoTypeInformation

    Write-Host "Full results exported to: $csvPath" -ForegroundColor Green

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
