# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an S3 JSON File Search Tool - a PowerShell-based utility for efficiently searching through large volumes (100,000+) of JSON files stored in AWS S3. The tool uses date-based filtering and parallel processing to quickly locate files containing specific search strings.

**Key Characteristics:**
- Pure PowerShell implementation (no compiled code)
- Supports Windows PowerShell 5.1+ and PowerShell 7+
- Uses AWS.Tools.S3 PowerShell module for S3 API interactions
- Two search methods: Standard (download-based) and Advanced (S3 Select server-side)

## Common Commands

### Setup and Testing
```powershell
# Initial setup - installs AWS.Tools.S3 and configures credentials
./Setup.ps1

# Validate setup and test permissions
./Test-Setup.ps1

# Test with specific bucket
./Test-Setup.ps1 -BucketName "your-bucket-name" -Region "us-west-1"
```

### Running Searches
```powershell
# Interactive mode (easiest for users)
./Run-Search.ps1

# Interactive with Advanced search
./Run-Search.ps1 -UseAdvanced

# Standard search (direct command line)
./Search-S3JsonFiles.ps1 -BucketName "bucket" -Prefix "path/" -SearchString "text" -TargetDate "2025-10-18"

# Advanced search with S3 Select
./Search-S3JsonFiles-Advanced.ps1 -BucketName "bucket" -Prefix "path/" -SearchString "text" -TargetDate "2025-10-18" -MaxParallel 20

# Search specific JSON field (Advanced only)
./Search-S3JsonFiles-Advanced.ps1 -BucketName "bucket" -Prefix "path/" -SearchString "error" -TargetDate "2025-10-18" -JsonPath "s.errorMessage"
```

### Testing and Development
```powershell
# Generate 100 test JSON files for local testing
python generate_test_files.py

# Test data is created in test_data/ directory
# One random file contains the string "golden"
```

### Git Operations
```powershell
# Check PowerShell script line endings (must be CRLF)
git ls-files --eol

# Common git operations
git status
git log --oneline -10
git diff
```

## Architecture

### Script Purpose and Relationships

**Setup Scripts:**
- `Setup.ps1` - Initial installation and credential configuration
- `Test-Setup.ps1` - Validates AWS credentials, modules, and IAM permissions

**Search Scripts:**
- `Run-Search.ps1` - Interactive wrapper that prompts for parameters and delegates to search scripts
- `Search-S3JsonFiles.ps1` - Standard search implementation (downloads files to temp, searches locally)
- `Search-S3JsonFiles-Advanced.ps1` - Advanced search using AWS S3 Select (server-side filtering)

**Test Utilities:**
- `generate_test_files.py` - Generates 100 sample JSON files with various structures for testing

### Core Search Algorithm

Both search scripts follow the same three-phase approach:

1. **Phase 1: Date Filtering**
   - Lists all S3 objects with specified prefix using `Get-S3Object`
   - Filters by `LastModified` timestamp (UTC) matching TargetDate
   - Only includes files with `.json` extension
   - Uses continuation tokens to handle large buckets (1000 objects per request)

2. **Phase 2: Parallel Content Search**
   - Standard: Downloads each file to temp directory using `Read-S3Object`, searches content locally
   - Advanced: Uses `Select-S3ObjectContent` with SQL expression for server-side search
   - Both use `ForEach-Object -Parallel` with configurable throttle limit (10-20 threads)
   - Results stored in `ConcurrentBag` for thread-safety

3. **Phase 3: Results Export**
   - Displays matching files with metadata (key, size, last modified)
   - Exports results to timestamped CSV: `search_results_YYYYMMDD_HHMMSS.csv`
   - Generates ready-to-use AWS CLI download commands

### Key Technical Patterns

**Thread-Safe Collections:**
```powershell
$matchingFiles = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()
# Used for collecting results from parallel operations
```

**Date Range Filtering:**
```powershell
$targetDateTime = [DateTime]::ParseExact($TargetDate, "yyyy-MM-dd", $null)
$startOfDay = $targetDateTime.Date
$endOfDay = $startOfDay.AddDays(1).AddSeconds(-1)
# Files filtered: LastModified >= startOfDay AND LastModified <= endOfDay
```

**S3 Select Query (Advanced):**
- Uses SQL-like syntax: `SELECT * FROM S3Object[*] s WHERE s.field LIKE '%searchstring%'`
- Automatic fallback to download method if S3 Select fails (malformed JSON)
- Requires `InputSerialization_JSON_Type = 'DOCUMENT'` for single JSON objects

**PowerShell Script Execution:**
- All scripts use `#!/usr/bin/env pwsh` shebang for cross-platform compatibility
- Line endings MUST be CRLF (enforced via .gitattributes) for Windows PowerShell compatibility

### IAM Permissions Required

**Minimum (Standard search):**
- `s3:ListBucket` - List objects and filter by date
- `s3:GetObject` - Download file contents

**Advanced search (S3 Select):**
- `s3:ListBucket`
- `s3:GetObject` (fallback)
- `s3:SelectObjectContent` - Server-side filtering

## Important Development Notes

### PowerShell Line Endings
**CRITICAL:** PowerShell scripts (.ps1) MUST use CRLF line endings. The repository includes `.gitattributes` that enforces this:
```
*.ps1 text eol=crlf
```
If scripts fail to run on Windows with syntax errors, check line endings are CRLF not LF.

### AWS Module Dependencies
- Primary module: `AWS.Tools.S3`
- Install via: `Install-Module -Name AWS.Tools.Installer -Force` then `Install-AWSToolsModule AWS.Tools.S3`
- Scripts use `-Scope CurrentUser` to avoid requiring admin rights
- Alternative: System-wide install with `-Scope AllUsers` (requires admin)

### Credential Configuration
- Stored in Windows Credential Manager (encrypted)
- Default profile name: "default"
- Check credentials: `Get-AWSCredential -ProfileName default`
- Test validity: `Get-STSCallerIdentity` returns account/user info

### Performance Tuning
- **MaxParallel Parameter:** Controls concurrent S3 operations
  - Standard: Default 10, safe range 5-20
  - Advanced: Default 20, can go 50-100 on EC2 with good network
  - Too high = out of memory, too low = slow
- **Date Filtering:** Critical for performance - reduces 100,000s of files to hundreds
- **S3 Select:** 10-100x faster than download method, but requires well-formed JSON

### Output Files
- CSV exports: `search_results_YYYYMMDD_HHMMSS.csv` (columns: Key, Size, LastModified)
- Temporary files: Standard method downloads to `[System.IO.Path]::GetTempFileName()` then auto-deletes
- No persistent local storage except CSV results

## Testing Strategy

### Local Testing
```powershell
# Generate test data
python generate_test_files.py

# This creates 100 files in test_data/ with one containing "golden"
# Use for unit testing search logic without S3 access
```

### Integration Testing
```powershell
# Validate setup completely
./Test-Setup.ps1 -BucketName "test-bucket" -Region "us-west-1"

# Tests:
# 1. PowerShell version compatibility
# 2. AWS.Tools.S3 module installation
# 3. AWS credential validity
# 4. S3 bucket access (ListBucket)
# 5. Object read permissions (GetObject)
```

### Expected Test Results
- Setup validation should show all green checkmarks
- Search should complete Phase 1 in seconds (date filter is fast)
- Phase 2 duration depends on file count after filter and MaxParallel setting
- CSV export confirms successful completion

## Common Issues and Solutions

### "Access Denied" Errors
- Verify IAM policy includes `s3:ListBucket` on bucket ARN
- Verify IAM policy includes `s3:GetObject` on object ARN (`bucket-name/*`)
- Check bucket policy doesn't explicitly deny access
- Confirm credentials: `Get-STSCallerIdentity`

### PowerShell Script Won't Run
- Check execution policy: `Get-ExecutionPolicy`
- Set if needed: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Verify line endings are CRLF: `git ls-files --eol`

### S3 Select Failures (Advanced Script)
- JSON must be well-formed (one object per file or JSONL)
- Script automatically falls back to download method
- Disable completely with: `-UseS3Select $false`

### Slow Performance
- Increase parallelism: `-MaxParallel 20` or higher
- Use Advanced script with S3 Select
- Verify date filter is working (check Phase 1 output)
- Run from EC2 in same region as bucket

### Out of Memory
- Reduce parallelism: `-MaxParallel 5`
- Use Advanced script (lower memory footprint)
- Process smaller date ranges

## Documentation Files

- `README.md` - User-facing documentation with quick start and examples
- `IT-MANAGER-GUIDE.md` - Comprehensive guide for IT managers covering permissions, security, compliance, deployment
- `CLAUDE.md` - This file, for future Claude Code instances

## Development Workflow

When modifying PowerShell scripts:
1. Edit the .ps1 file
2. **Ensure line endings remain CRLF** (editor should respect .gitattributes)
3. Test locally with `./Test-Setup.ps1`
4. Test search functionality with test_data/ or real S3 bucket
5. Commit with descriptive message explaining the change
6. .gitattributes automatically enforces CRLF on commit

When adding new features:
- Follow existing pattern of three-phase search (filter → search → export)
- Use `ConcurrentBag` for thread-safe result collection
- Maintain `-ThrottleLimit` parameter for parallel operations
- Include progress updates for long-running operations
- Export results to CSV with timestamp

## Repository Structure

```
├── Search-S3JsonFiles.ps1              # Standard search (download-based)
├── Search-S3JsonFiles-Advanced.ps1     # Advanced search (S3 Select)
├── Run-Search.ps1                      # Interactive wrapper
├── Setup.ps1                           # Initial setup script
├── Test-Setup.ps1                      # Setup validation script
├── generate_test_files.py              # Test data generator
├── test_data/                          # Generated test JSON files
│   └── test_file_*.json                # 100 test files
├── README.md                           # User documentation
├── IT-MANAGER-GUIDE.md                 # IT manager documentation
├── .gitattributes                      # Enforces CRLF for .ps1 files
└── CLAUDE.md                           # This file
```
