#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup script for S3 JSON Search Tool

.DESCRIPTION
    Installs prerequisites and configures AWS credentials
#>

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  S3 JSON Search Tool - Setup & Install  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVersion" -ForegroundColor White

if ($psVersion.Major -lt 7) {
    Write-Host "⚠ Warning: PowerShell 7+ recommended for best performance" -ForegroundColor Yellow
    Write-Host "  Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
    Write-Host ""
}

# Check if AWS.Tools.S3 is installed
Write-Host "Checking AWS PowerShell modules..." -ForegroundColor Yellow

$s3Module = Get-Module -ListAvailable -Name AWS.Tools.S3
if (-not $s3Module) {
    Write-Host "AWS.Tools.S3 module not found. Installing..." -ForegroundColor Yellow
    
    try {
        # Install AWS.Tools.Installer first
        Install-Module -Name AWS.Tools.Installer -Force -AllowClobber -Scope CurrentUser
        
        # Install S3 module
        Install-AWSToolsModule AWS.Tools.S3 -Force -AllowClobber
        
        Write-Host "✓ AWS.Tools.S3 installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Error installing AWS.Tools.S3: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install manually:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name AWS.Tools.S3 -Force" -ForegroundColor White
        exit 1
    }
} else {
    Write-Host "✓ AWS.Tools.S3 module found (version $($s3Module.Version))" -ForegroundColor Green
}

Write-Host ""

# Check AWS credentials
Write-Host "Checking AWS credentials..." -ForegroundColor Yellow

$configureCredentials = $false

try {
    $credentials = Get-AWSCredential -ProfileName default -ErrorAction SilentlyContinue
    if ($credentials) {
        Write-Host "✓ AWS credentials found (profile: default)" -ForegroundColor Green
        
        # Test credentials
        Write-Host "Testing credentials..." -ForegroundColor Yellow
        $caller = Get-STSCallerIdentity -ErrorAction Stop
        Write-Host "✓ Credentials valid - Account: $($caller.Account), User: $($caller.Arn.Split('/')[-1])" -ForegroundColor Green
    } else {
        $configureCredentials = $true
    }
} catch {
    Write-Host "! No valid AWS credentials found" -ForegroundColor Yellow
    $configureCredentials = $true
}

Write-Host ""

if ($configureCredentials) {
    Write-Host "Would you like to configure AWS credentials now? (Y/n)" -ForegroundColor Yellow
    $configure = Read-Host
    
    if ($configure -ne 'n' -and $configure -ne 'N') {
        Write-Host ""
        Write-Host "Enter your AWS credentials:" -ForegroundColor Cyan
        
        $accessKey = Read-Host "AWS Access Key ID"
        $secretKey = Read-Host "AWS Secret Access Key" -AsSecureString
        
        try {
            $secretKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretKey)
            )
            
            Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKeyPlain -StoreAs default
            
            Write-Host "✓ Credentials saved successfully" -ForegroundColor Green
            
            # Test new credentials
            Write-Host "Testing credentials..." -ForegroundColor Yellow
            $caller = Get-STSCallerIdentity -ErrorAction Stop
            Write-Host "✓ Credentials valid - Account: $($caller.Account)" -ForegroundColor Green
            
        } catch {
            Write-Host "✗ Error saving credentials: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: ./Run-Search.ps1" -ForegroundColor White
Write-Host "     (Interactive search with guided prompts)" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Or run directly:" -ForegroundColor White
Write-Host "     ./Search-S3JsonFiles.ps1 -BucketName 'mybucket' -Prefix 'data/' -SearchString 'text' -TargetDate '2025-10-18'" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. For advanced features (S3 Select):" -ForegroundColor White
Write-Host "     ./Search-S3JsonFiles-Advanced.ps1 -BucketName 'mybucket' -Prefix 'data/' -SearchString 'text' -TargetDate '2025-10-18'" -ForegroundColor Gray
Write-Host ""
Write-Host "See README.md for full documentation" -ForegroundColor Cyan
Write-Host ""
