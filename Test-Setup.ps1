#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that the S3 JSON Search Tool is properly configured

.DESCRIPTION
    Tests AWS credentials, PowerShell version, required modules, and S3 access

.PARAMETER BucketName
    Optional: Test access to a specific S3 bucket

.PARAMETER Region
    AWS Region to test (default: us-west-1)

.EXAMPLE
    ./Test-Setup.ps1

.EXAMPLE
    ./Test-Setup.ps1 -BucketName "my-test-bucket" -Region "us-east-1"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BucketName,

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-west-1"
)

Write-Host ""
Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  S3 JSON Search Tool - Setup Validation  ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$allTestsPassed = $true

# Test 1: PowerShell Version
Write-Host "[1/5] Testing PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "  PowerShell version: $psVersion" -ForegroundColor White

if ($psVersion.Major -ge 7) {
    Write-Host "  ✓ PowerShell 7+ detected (optimal)" -ForegroundColor Green
} elseif ($psVersion.Major -ge 5) {
    Write-Host "  ⚠ PowerShell $($psVersion.Major) detected (works, but 7+ recommended)" -ForegroundColor Yellow
    Write-Host "    Download PowerShell 7: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Gray
} else {
    Write-Host "  ✗ PowerShell version too old (5.1+ required)" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 2: AWS PowerShell Module
Write-Host "[2/5] Testing AWS PowerShell modules..." -ForegroundColor Yellow

$s3Module = Get-Module -ListAvailable -Name AWS.Tools.S3
if ($s3Module) {
    Write-Host "  ✓ AWS.Tools.S3 module installed (version: $($s3Module.Version))" -ForegroundColor Green

    # Try to import it
    try {
        Import-Module AWS.Tools.S3 -ErrorAction Stop
        Write-Host "  ✓ AWS.Tools.S3 module loaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Error loading AWS.Tools.S3: $_" -ForegroundColor Red
        $allTestsPassed = $false
    }
} else {
    Write-Host "  ✗ AWS.Tools.S3 module not found" -ForegroundColor Red
    Write-Host "    Install with: Install-Module -Name AWS.Tools.S3 -Force" -ForegroundColor Gray
    $allTestsPassed = $false
}
Write-Host ""

# Test 3: AWS Credentials
Write-Host "[3/5] Testing AWS credentials..." -ForegroundColor Yellow

try {
    $credentials = Get-AWSCredential -ProfileName default -ErrorAction SilentlyContinue

    if ($credentials) {
        Write-Host "  ✓ AWS credentials found (profile: default)" -ForegroundColor Green

        # Test by getting caller identity
        try {
            $caller = Get-STSCallerIdentity -Region $Region -ErrorAction Stop
            Write-Host "  ✓ Credentials are valid" -ForegroundColor Green
            Write-Host "    Account: $($caller.Account)" -ForegroundColor Gray
            Write-Host "    User/Role: $($caller.Arn.Split('/')[-1])" -ForegroundColor Gray
        } catch {
            Write-Host "  ✗ Credentials found but invalid: $_" -ForegroundColor Red
            $allTestsPassed = $false
        }
    } else {
        Write-Host "  ✗ No AWS credentials found" -ForegroundColor Red
        Write-Host "    Run: ./Setup.ps1 to configure credentials" -ForegroundColor Gray
        $allTestsPassed = $false
    }
} catch {
    Write-Host "  ✗ Error checking credentials: $_" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 4: S3 Access (if bucket provided)
if ($BucketName) {
    Write-Host "[4/5] Testing S3 bucket access..." -ForegroundColor Yellow
    Write-Host "  Testing bucket: $BucketName" -ForegroundColor White

    try {
        # Try to list objects (just first page)
        $objects = Get-S3Object -BucketName $BucketName -MaxKeys 1 -Region $Region -ErrorAction Stop
        Write-Host "  ✓ Successfully accessed bucket '$BucketName'" -ForegroundColor Green

        # Try to get bucket location
        $location = Get-S3BucketLocation -BucketName $BucketName -ErrorAction SilentlyContinue
        if ($location) {
            Write-Host "    Bucket region: $($location.Value)" -ForegroundColor Gray
        }

    } catch {
        Write-Host "  ✗ Error accessing bucket: $_" -ForegroundColor Red
        Write-Host "    Verify: 1) Bucket exists, 2) Correct region, 3) IAM permissions" -ForegroundColor Gray
        $allTestsPassed = $false
    }
} else {
    Write-Host "[4/5] Skipping S3 bucket access test (no bucket specified)" -ForegroundColor Gray
    Write-Host "  To test bucket access, run:" -ForegroundColor Gray
    Write-Host "    ./Test-Setup.ps1 -BucketName 'your-bucket-name'" -ForegroundColor Gray
}
Write-Host ""

# Test 5: Required IAM Permissions (if bucket provided)
if ($BucketName -and $allTestsPassed) {
    Write-Host "[5/5] Testing required IAM permissions..." -ForegroundColor Yellow

    $requiredPermissions = @{
        "s3:ListBucket" = $false
        "s3:GetObject" = $false
    }

    # Test ListBucket
    try {
        Get-S3Object -BucketName $BucketName -MaxKeys 1 -Region $Region -ErrorAction Stop | Out-Null
        $requiredPermissions["s3:ListBucket"] = $true
        Write-Host "  ✓ s3:ListBucket - OK" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ s3:ListBucket - FAILED" -ForegroundColor Red
        $allTestsPassed = $false
    }

    # Test GetObject (try to read first object if exists)
    try {
        $firstObj = Get-S3Object -BucketName $BucketName -MaxKeys 1 -Region $Region -ErrorAction Stop
        if ($firstObj -and $firstObj.Key) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Read-S3Object -BucketName $BucketName -Key $firstObj.Key -File $tempFile -Region $Region -ErrorAction Stop | Out-Null
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            $requiredPermissions["s3:GetObject"] = $true
            Write-Host "  ✓ s3:GetObject - OK" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ s3:GetObject - Cannot test (bucket empty)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ s3:GetObject - FAILED" -ForegroundColor Red
        $allTestsPassed = $false
    }

    # Note about S3 Select (optional)
    Write-Host "  ℹ s3:SelectObjectContent - Optional (for Advanced search)" -ForegroundColor Cyan

} else {
    Write-Host "[5/5] Skipping IAM permissions test (no bucket specified or previous tests failed)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
if ($allTestsPassed) {
    Write-Host "✓ All tests passed! Ready to search." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  Run: ./Run-Search.ps1" -ForegroundColor White
    Write-Host "  Or:  ./Search-S3JsonFiles.ps1 -BucketName 'mybucket' -Prefix 'path/' -SearchString 'text' -TargetDate '2025-01-15'" -ForegroundColor White
} else {
    Write-Host "✗ Some tests failed. Please fix the issues above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "  • Install modules: ./Setup.ps1" -ForegroundColor White
    Write-Host "  • Configure credentials: ./Setup.ps1" -ForegroundColor White
    Write-Host "  • Check IAM permissions in AWS console" -ForegroundColor White
}
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Exit with appropriate code
if ($allTestsPassed) {
    exit 0
} else {
    exit 1
}
