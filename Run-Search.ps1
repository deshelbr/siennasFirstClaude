#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive wrapper for S3 JSON search tool

.DESCRIPTION
    Provides an easy-to-use interface for searching S3 JSON files
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$UseAdvanced
)

Write-Host ""
Write-Host "S3 JSON File Search - Quick Start" -ForegroundColor Cyan
Write-Host ""

# Gather inputs
$bucketName = Read-Host "Enter S3 bucket name"
$prefix = Read-Host "Enter prefix/directory path (e.g. data/ or leave empty)"
$searchString = Read-Host "Enter the string to search for"
$searchString2 = Read-Host "Enter second string (optional - both must be present, or leave empty)"

Write-Host ""
Write-Host "Date options:" -ForegroundColor Yellow
$dateMode = Read-Host "Use (S)ingle date or (R)ange? (S/R)"

if ($dateMode -eq 'R' -or $dateMode -eq 'r') {
    $startDate = Read-Host "Enter start date (yyyy-MM-dd e.g. 2025-10-15)"
    $endDate = Read-Host "Enter end date (yyyy-MM-dd e.g. 2025-10-20)"
    $targetDate = $null
} else {
    $targetDate = Read-Host "Enter target date (yyyy-MM-dd e.g. 2025-10-18)"
    $startDate = $null
    $endDate = $null
}

Write-Host ""
Write-Host "Optional settings (press Enter to use defaults):" -ForegroundColor Yellow

$region = Read-Host "AWS Region (default: us-west-1)"
if ([string]::IsNullOrWhiteSpace($region)) {
    $region = "us-west-1"
}

$maxParallelInput = Read-Host "Max parallel threads (default: 10 for standard, 20 for advanced)"
if ([string]::IsNullOrWhiteSpace($maxParallelInput)) {
    $maxParallel = if ($UseAdvanced) { 20 } else { 10 }
} else {
    $maxParallel = [int]$maxParallelInput
}

$downloadResponse = Read-Host "Download matching files locally? (Y/n)"
$downloadMatches = $downloadResponse -ne 'n' -and $downloadResponse -ne 'N'

Write-Host ""
Write-Host "Starting search with the following parameters:" -ForegroundColor Green
Write-Host "  Bucket: $bucketName"
Write-Host "  Prefix: $prefix"
Write-Host "  Search: $searchString"
if ($searchString2) {
    Write-Host "  Search 2: $searchString2 (both required)"
}
if ($targetDate) {
    Write-Host "  Date: $targetDate"
} else {
    Write-Host "  Date Range: $startDate to $endDate"
}
Write-Host "  Region: $region"
Write-Host "  Parallel: $maxParallel"
Write-Host "  Download: $downloadMatches"
Write-Host ""

$confirmation = Read-Host "Continue? (Y/n)"
if ($confirmation -eq 'n' -or $confirmation -eq 'N') {
    Write-Host "Search cancelled." -ForegroundColor Yellow
    exit 0
}

# Execute appropriate script
if ($UseAdvanced) {
    $scriptPath = "./Search-S3JsonFiles-Advanced.ps1"
} else {
    $scriptPath = "./Search-S3JsonFiles.ps1"
}

$params = @{
    BucketName = $bucketName
    Prefix = $prefix
    SearchString = $searchString
    Region = $region
    MaxParallel = $maxParallel
}

if ($searchString2) {
    $params['SearchString2'] = $searchString2
}

if ($targetDate) {
    $params['TargetDate'] = $targetDate
} else {
    $params['StartDate'] = $startDate
    $params['EndDate'] = $endDate
}

if ($downloadMatches) {
    $params['DownloadMatches'] = $true
}

Write-Host ""
& $scriptPath @params