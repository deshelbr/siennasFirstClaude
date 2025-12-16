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
                Write-Host "[DEBUG] ========== CREDENTIAL VALIDATION ==========" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Access Key ID length: $($accessKey.Length) characters" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Access Key ID first 8 chars: $($accessKey.Substring(0, [Math]::Min(8, $accessKey.Length)))" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Access Key ID last 4 chars: $($accessKey.Substring([Math]::Max(0, $accessKey.Length - 4)))" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Access Key ID (full): $accessKey" -ForegroundColor DarkGray

                Write-Host "[DEBUG] Secret Key length: $($secretKeyPlain.Length) characters" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Secret Key first 4 chars: $($secretKeyPlain.Substring(0, [Math]::Min(4, $secretKeyPlain.Length)))" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Secret Key last 4 chars: $($secretKeyPlain.Substring([Math]::Max(0, $secretKeyPlain.Length - 4)))" -ForegroundColor DarkGray

                Write-Host "[DEBUG] Credential type: $(if ($isTemporary) { 'Temporary (ASIA)' } else { 'Permanent (AKIA)' })" -ForegroundColor DarkGray

                if ($isTemporary) {
                    Write-Host "[DEBUG] Session Token length: $($sessionToken.Length) characters" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Session Token first 20 chars: $($sessionToken.Substring(0, [Math]::Min(20, $sessionToken.Length)))" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Session Token last 20 chars: $($sessionToken.Substring([Math]::Max(0, $sessionToken.Length - 20)))" -ForegroundColor DarkGray

                    # Check for common issues
                    $hasLeadingSpace = $sessionToken.StartsWith(" ")
                    $hasTrailingSpace = $sessionToken.EndsWith(" ")
                    $hasLineBreaks = $sessionToken.Contains("`n") -or $sessionToken.Contains("`r")
                    $hasTabs = $sessionToken.Contains("`t")

                    Write-Host "[DEBUG] Session Token has leading space: $hasLeadingSpace" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Session Token has trailing space: $hasTrailingSpace" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Session Token has line breaks: $hasLineBreaks" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Session Token has tabs: $hasTabs" -ForegroundColor DarkGray

                    if ($hasLeadingSpace -or $hasTrailingSpace -or $hasLineBreaks -or $hasTabs) {
                        Write-Host "[DEBUG] ⚠ WARNING: Session token contains whitespace characters that may cause issues!" -ForegroundColor Yellow

                        # Clean the token
                        $cleanedToken = $sessionToken.Trim() -replace "`n", "" -replace "`r", "" -replace "`t", ""
                        if ($cleanedToken.Length -ne $sessionToken.Length) {
                            Write-Host "[DEBUG] Cleaned token length: $($cleanedToken.Length) (removed $($sessionToken.Length - $cleanedToken.Length) chars)" -ForegroundColor DarkGray
                            $sessionToken = $cleanedToken
                            Write-Host "[DEBUG] Using cleaned session token" -ForegroundColor Yellow
                        }
                    }
                }

                Write-Host "[DEBUG] Using region: $selectedRegion" -ForegroundColor DarkGray
                Write-Host "[DEBUG] =========================================" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Calling Set-AWSCredential with profile 'default'" -ForegroundColor DarkGray
            }

            # Save credentials with or without session token
            if ($isTemporary) {
                Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKeyPlain -SessionToken $sessionToken -StoreAs default
            } else {
                Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKeyPlain -StoreAs default
            }

            Write-Host "✓ Credentials saved successfully" -ForegroundColor Green

            # Verify credentials were saved correctly
            if ($Debug) {
                Write-Host "[DEBUG] Verifying saved credentials..." -ForegroundColor DarkGray
                $savedCreds = Get-AWSCredential -ProfileName default
                if ($savedCreds) {
                    $savedAccessKey = $savedCreds.GetCredentials().AccessKey
                    Write-Host "[DEBUG] Saved Access Key: $savedAccessKey" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Saved Access Key matches input: $($savedAccessKey -eq $accessKey)" -ForegroundColor DarkGray

                    # Check if session token is present for temporary credentials
                    if ($isTemporary) {
                        $hasSessionToken = $savedCreds.GetCredentials().Token -ne $null
                        Write-Host "[DEBUG] Session token was saved: $hasSessionToken" -ForegroundColor DarkGray
                        if ($hasSessionToken) {
                            Write-Host "[DEBUG] Saved session token length: $($savedCreds.GetCredentials().Token.Length)" -ForegroundColor DarkGray
                        }
                    }
                }
            }

            # Test new credentials
            Write-Host "Testing credentials..." -ForegroundColor Yellow
            if ($Debug) {
                Write-Host "[DEBUG] ========== TESTING CREDENTIALS ==========" -ForegroundColor DarkGray
                Write-Host "[DEBUG] Calling Get-STSCallerIdentity with region: $selectedRegion" -ForegroundColor DarkGray
                Write-Host "[DEBUG] This makes an AWS STS API call to verify credentials" -ForegroundColor DarkGray
            }

            try {
                $caller = Get-STSCallerIdentity -Region $selectedRegion -ErrorAction Stop
                Write-Host "✓ Credentials valid - Account: $($caller.Account)" -ForegroundColor Green

                if ($Debug) {
                    Write-Host "[DEBUG] Caller Identity ARN: $($caller.Arn)" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Caller User ID: $($caller.UserId)" -ForegroundColor DarkGray
                }
            } catch {
                # Detailed error analysis
                if ($Debug) {
                    Write-Host "[DEBUG] ========== AWS API ERROR DETAILS ==========" -ForegroundColor Red
                    Write-Host "[DEBUG] Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray
                    Write-Host "[DEBUG] Error Message: $($_.Exception.Message)" -ForegroundColor DarkGray

                    # Check for specific AWS error codes
                    if ($_.Exception.Message -like "*security token*") {
                        Write-Host "[DEBUG] ERROR CATEGORY: Invalid Session Token" -ForegroundColor Red
                        Write-Host "[DEBUG] This typically means:" -ForegroundColor Yellow
                        Write-Host "[DEBUG]   1. The session token is malformed or truncated" -ForegroundColor Yellow
                        Write-Host "[DEBUG]   2. The session token has expired" -ForegroundColor Yellow
                        Write-Host "[DEBUG]   3. The session token doesn't match the access key/secret" -ForegroundColor Yellow
                    } elseif ($_.Exception.Message -like "*InvalidClientTokenId*") {
                        Write-Host "[DEBUG] ERROR CATEGORY: Invalid Access Key" -ForegroundColor Red
                        Write-Host "[DEBUG] The access key ID is not recognized" -ForegroundColor Yellow
                    } elseif ($_.Exception.Message -like "*SignatureDoesNotMatch*") {
                        Write-Host "[DEBUG] ERROR CATEGORY: Invalid Secret Key" -ForegroundColor Red
                        Write-Host "[DEBUG] The secret access key is incorrect" -ForegroundColor Yellow
                    }

                    # Additional diagnostics
                    Write-Host "[DEBUG] Attempting to retrieve raw credential values for comparison..." -ForegroundColor DarkGray
                    $testCreds = Get-AWSCredential -ProfileName default
                    if ($testCreds) {
                        $testCredsObject = $testCreds.GetCredentials()
                        Write-Host "[DEBUG] Retrieved Access Key: $($testCredsObject.AccessKey)" -ForegroundColor DarkGray
                        Write-Host "[DEBUG] Retrieved Secret Key length: $($testCredsObject.SecretKey.Length)" -ForegroundColor DarkGray
                        Write-Host "[DEBUG] Retrieved Token length: $(if ($testCredsObject.Token) { $testCredsObject.Token.Length } else { 'NULL' })" -ForegroundColor DarkGray

                        Write-Host "[DEBUG] Original vs Saved comparison:" -ForegroundColor DarkGray
                        Write-Host "[DEBUG]   Access Key match: $($testCredsObject.AccessKey -eq $accessKey)" -ForegroundColor DarkGray
                        Write-Host "[DEBUG]   Secret Key match: $($testCredsObject.SecretKey -eq $secretKeyPlain)" -ForegroundColor DarkGray
                        if ($isTemporary) {
                            Write-Host "[DEBUG]   Session Token match: $($testCredsObject.Token -eq $sessionToken)" -ForegroundColor DarkGray
                        }
                    }

                    Write-Host "[DEBUG] =========================================" -ForegroundColor Red
                }

                # Re-throw the error to be caught by outer catch block
                throw
            }

            # Update Region variable for final output
            $Region = $selectedRegion

        } catch {
            Write-Host "✗ Error testing credentials: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
            Write-Host "  1. Verify credentials are from the AWS Access Portal (SSO)" -ForegroundColor White
            Write-Host "  2. Ensure all three values (Access Key, Secret, Token) are from the SAME credential set" -ForegroundColor White
            Write-Host "  3. Copy the session token carefully - it should be 800-900+ characters" -ForegroundColor White
            Write-Host "  4. Check if credentials have expired (temporary credentials typically last 1-12 hours)" -ForegroundColor White
            Write-Host "  5. Try generating fresh credentials from AWS Access Portal" -ForegroundColor White
            Write-Host ""
            Write-Host "For detailed diagnostics, see the DEBUG output above (if -Debug flag is used)" -ForegroundColor Yellow
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
