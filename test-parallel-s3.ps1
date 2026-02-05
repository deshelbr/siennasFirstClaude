#!/usr/bin/env pwsh

$keys = @("data-test-1/test_file_001.json")

$keys | ForEach-Object -Parallel {
    Import-Module AWS.Tools.S3 -ErrorAction SilentlyContinue

    $tempFile = [System.IO.Path]::GetTempFileName()

    Write-Host "Downloading $_"
    Read-S3Object -BucketName "json-search-testing" -Key $_ -File $tempFile

    $content = Get-Content -Path $tempFile -Raw
    Write-Host "Content length: $($content.Length)"

    Remove-Item $tempFile -Force
} -ThrottleLimit 1

Write-Host "Done"
