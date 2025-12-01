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
$targetDate = Read-Host "Enter target date (yyyy-MM-dd e.g. 2025-10-18)"

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

Write-Host ""
Write-Host "Starting search with the following parameters:" -ForegroundColor Green
Write-Host "  Bucket: $bucketName"
Write-Host "  Prefix: $prefix"
Write-Host "  Search: $searchString"
Write-Host "  Date: $targetDate"
Write-Host "  Region: $region"
Write-Host "  Parallel: $maxParallel"
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
    TargetDate = $targetDate
    Region = $region
    MaxParallel = $maxParallel
}

Write-Host ""
& $scriptPath @params