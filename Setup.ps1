#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup script for S3 JSON Search Tool

.DESCRIPTION
    Installs prerequisites and configures AWS credentials

.PARAMETER Region
    AWS region to use for credential validation (default: us-east-1)

.PARAMETER Debug
    Enable detailed debug logging

.EXAMPLE
    ./Setup.ps1

.EXAMPLE
    ./Setup.ps1 -Region us-west-2

.EXAMPLE
    ./Setup.ps1 -Region us-east-1 -Debug
#>

param(
    [string]$Region = "us-east-1",
    [switch]$Debug
)

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  S3 JSON Search Tool - Setup & Install  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($Debug) {
    Write-Host "[DEBUG] Region: $Region" -ForegroundColor DarkGray
    Write-Host "[DEBUG] Debug mode enabled" -ForegroundColor DarkGray
    Write-Host ""
}

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVersion" -ForegroundColor White

if ($psVersion.Major -lt 7) {
    Write-Host "⚠ Warning: PowerShell 7+ recommended for best performance" -ForegroundColor Yellow
    Write-Host "  Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
    Write-Host ""
}

# Check if AWS.Tools modules are installed
Write-Host "Checking AWS PowerShell modules..." -ForegroundColor Yellow

$s3Module = Get-Module -ListAvailable -Name AWS.Tools.S3
$stsModule = Get-Module -ListAvailable -Name AWS.Tools.SecurityToken

if (-not $s3Module -or -not $stsModule) {
    Write-Host "Required AWS modules not found. Installing..." -ForegroundColor Yellow

    try {
        # Install AWS.Tools.Installer first
        Install-Module -Name AWS.Tools.Installer -Force -AllowClobber -Scope CurrentUser

        # Install required modules
        Install-AWSToolsModule AWS.Tools.S3,AWS.Tools.SecurityToken -Force -AllowClobber

        Write-Host "✓ AWS.Tools.S3 installed successfully" -ForegroundColor Green
        Write-Host "✓ AWS.Tools.SecurityToken installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Error installing AWS modules: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install manually:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name AWS.Tools.S3 -Force" -ForegroundColor White
        Write-Host "  Install-Module -Name AWS.Tools.SecurityToken -Force" -ForegroundColor White
        exit 1
    }
} else {
    Write-Host "✓ AWS.Tools.S3 module found (version $($s3Module.Version))" -ForegroundColor Green
    Write-Host "✓ AWS.Tools.SecurityToken module found (version $($stsModule.Version))" -ForegroundColor Green
}

Write-Host ""

# Check AWS credentials
Write-Host "Checking AWS credentials..." -ForegroundColor Yellow

$configureCredentials = $false

try {
    if ($Debug) {
        Write-Host "[DEBUG] Looking for AWS credential profile 'default'" -ForegroundColor DarkGray
    }

    $credentials = Get-AWSCredential -ProfileName default -ErrorAction SilentlyContinue
    if ($credentials) {
        Write-Host "✓ AWS credentials found (profile: default)" -ForegroundColor Green

        if ($Debug) {
            Write-Host "[DEBUG] Access Key ID: $($credentials.GetCredentials().AccessKey)" -ForegroundColor DarkGray
        }

        # Test credentials
        Write-Host "Testing credentials..." -ForegroundColor Yellow
        if ($Debug) {
            Write-Host "[DEBUG] Calling Get-STSCallerIdentity with region: $Region" -ForegroundColor DarkGray
        }

        $caller = Get-STSCallerIdentity -Region $Region -ErrorAction Stop
        Write-Host "✓ Credentials valid - Account: $($caller.Account), User: $($caller.Arn.Split('/')[-1])" -ForegroundColor Green
    } else {
        if ($Debug) {
            Write-Host "[DEBUG] No credentials found in profile 'default'" -ForegroundColor DarkGray
        }
        $configureCredentials = $true
    }
} catch {
    Write-Host "! No valid AWS credentials found" -ForegroundColor Yellow
    if ($Debug) {
        Write-Host "[DEBUG] Error type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray
        Write-Host "[DEBUG] Error message: $($_.Exception.Message)" -ForegroundColor DarkGray
        Write-Host "[DEBUG] Error details: $_" -ForegroundColor DarkGray
    }
    $configureCredentials = $true
}

Write-Host ""

if ($configureCredentials) {
    Write-Host "Would you like to configure AWS credentials now? (Y/n)" -ForegroundColor Yellow
    $configure = Read-Host

    if ($configure -ne 'n' -and $configure -ne 'N') {
        Write-Host ""

        # Prompt for region
        Write-Host "AWS Region Configuration:" -ForegroundColor Cyan
        Write-Host "Common regions:" -ForegroundColor Gray
        Write-Host "  1. us-east-1 (US East - N. Virginia)" -ForegroundColor Gray
        Write-Host "  2. us-west-2 (US West - Oregon)" -ForegroundColor Gray
        Write-Host "  3. eu-west-1 (Europe - Ireland)" -ForegroundColor Gray
        Write-Host "  4. ap-southeast-1 (Asia Pacific - Singapore)" -ForegroundColor Gray
        Write-Host "  5. Other (specify)" -ForegroundColor Gray
        Write-Host ""
        $regionChoice = Read-Host "Select region (1-5, or press Enter for default: $Region)"

        $selectedRegion = $Region
        switch ($regionChoice) {
            "1" { $selectedRegion = "us-east-1" }
            "2" { $selectedRegion = "us-west-2" }
            "3" { $selectedRegion = "eu-west-1" }
            "4" { $selectedRegion = "ap-southeast-1" }
            "5" {
                $selectedRegion = Read-Host "Enter AWS region (e.g., us-west-1, eu-central-1)"
            }
            "" { $selectedRegion = $Region }
            default { $selectedRegion = $regionChoice }
        }

        Write-Host "Using region: $selectedRegion" -ForegroundColor Green
        Write-Host ""

        # Prompt for credentials
        Write-Host "Enter your AWS credentials:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Credential Types:" -ForegroundColor Gray
        Write-Host "  • Permanent (IAM User): Access Key starts with AKIA" -ForegroundColor Gray
        Write-Host "  • Temporary (SSO/Assumed Role): Access Key starts with ASIA (requires session token)" -ForegroundColor Gray
        Write-Host ""

        $accessKey = Read-Host "AWS Access Key ID"
        $secretKey = Read-Host "AWS Secret Access Key" -AsSecureString

        # Detect if temporary credentials are needed
        $isTemporary = $accessKey.StartsWith("ASIA")
        $sessionToken = $null

        if ($isTemporary) {
            Write-Host ""
            Write-Host "⚠ Temporary credentials detected (ASIA prefix)" -ForegroundColor Yellow
            Write-Host "Session token required for temporary credentials" -ForegroundColor Yellow
            $sessionTokenSecure = Read-Host "AWS Session Token" -AsSecureString

            $sessionToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sessionTokenSecure)
            )

            Write-Host ""
            Write-Host "⚠ Note: Temporary credentials expire (typically 1-12 hours)" -ForegroundColor Yellow
            Write-Host "You'll need to re-run Setup.ps1 when they expire" -ForegroundColor Yellow
        }

        try {
            if ($Debug) {
                Write-Host "[DEBUG] Converting secure string to plain text" -ForegroundColor DarkGray
            }

            $secretKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretKey)
            )

            if ($Debug) {
                Write-Host "[DEBUG] Access Key ID length: $($accessKey.Length) characters" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Secret Key length: $($secretKeyPlain.Length) characters" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Access Key ID: $accessKey" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Credential type: $(if ($isTemporary) { 'Temporary (ASIA)' } else { 'Permanent (AKIA)' })" -ForegroundColor DarkGray
                if ($isTemporary) {
                    Write-Host "[DEBUG] Session Token length: $($sessionToken.Length) characters" -ForegroundColor DarkGray
                }
                Write-Host "[DEBUG] Using region: $selectedRegion" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Calling Set-AWSCredential with profile 'default'" -ForegroundColor DarkGray
            }

            # Save credentials with or without session token
            if ($isTemporary) {
                Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKeyPlain -SessionToken $sessionToken -StoreAs default
            } else {
                Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKeyPlain -StoreAs default
            }

            Write-Host "✓ Credentials saved successfully" -ForegroundColor Green

            # Test new credentials
            Write-Host "Testing credentials..." -ForegroundColor Yellow
            if ($Debug) {
                Write-Host "[DEBUG] Calling Get-STSCallerIdentity with region: $selectedRegion" -ForegroundColor DarkGray
            }

            $caller = Get-STSCallerIdentity -Region $selectedRegion -ErrorAction Stop
            Write-Host "✓ Credentials valid - Account: $($caller.Account)" -ForegroundColor Green

            # Update Region variable for final output
            $Region = $selectedRegion

        } catch {
            Write-Host "✗ Error saving credentials: $_" -ForegroundColor Red

            if ($Debug) {
                Write-Host "" -ForegroundColor Red
                Write-Host "[DEBUG] Full error details:" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Error type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Error message: $($_.Exception.Message)" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Stack trace:" -ForegroundColor DarkGray
                Write-Host $_.Exception.StackTrace -ForegroundColor DarkGray

                if ($_.Exception.InnerException) {
                    Write-Host "[DEBUG] Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor DarkGray
                }

                Write-Host "" -ForegroundColor Red
                Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
                Write-Host "  1. Verify Access Key ID has no spaces: '$accessKey'" -ForegroundColor White
                Write-Host "  2. Check Access Key ID length (should be 20 chars): $($accessKey.Length)" -ForegroundColor White
                Write-Host "  3. Check Secret Key length (should be 40 chars): $($secretKeyPlain.Length)" -ForegroundColor White
                if ($isTemporary) {
                    Write-Host "  4. Check Session Token length (should be 300+ chars): $($sessionToken.Length)" -ForegroundColor White
                    Write-Host "  5. Verify token hasn't expired - try generating new temporary credentials" -ForegroundColor White
                } else {
                    Write-Host "  4. Verify the key is Active in AWS IAM Console" -ForegroundColor White
                    Write-Host "  5. Try a different region: ./Setup.ps1 -Region us-west-2 -Debug" -ForegroundColor White
                }
            }
        }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Region: $Region" -ForegroundColor White
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
Write-Host "Setup Options:" -ForegroundColor Cyan
Write-Host "  ./Setup.ps1 -Region <region>           # Use different AWS region" -ForegroundColor Gray
Write-Host "  ./Setup.ps1 -Debug                     # Enable debug logging" -ForegroundColor Gray
Write-Host ""
Write-Host "See README.md for full documentation" -ForegroundColor Cyan
Write-Host ""
