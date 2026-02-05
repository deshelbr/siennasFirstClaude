# S3 JSON File Search Tool

Efficiently search through hundreds of thousands of JSON files in AWS S3 by filtering on creation date and searching content in parallel.

## Features

- ✅ **Date-based filtering** - Single date or date range support for flexible searching
- ✅ **Multi-string search** - Search for files containing multiple strings (AND logic)
- ✅ **Parallel processing** - Search multiple files simultaneously for fast results
- ✅ **Two search methods**:
  - Standard: Downloads and searches files (reliable, works with any JSON)
  - Advanced: Uses S3 Select for server-side searching (faster, less data transfer)
- ✅ **Progress tracking** - Real-time updates on search progress
- ✅ **CSV export** - Results automatically exported for further analysis
- ✅ **Automatic downloads** - Optionally download matching files to local folder
- ✅ **Download commands** - Ready-to-use AWS CLI commands for manual retrieval

## Prerequisites

1. **AWS PowerShell Module**
   ```powershell
   Install-Module -Name AWS.Tools.S3 -Force
   ```

2. **AWS Credentials Configured**
   ```powershell
   # Configure AWS credentials
   Set-AWSCredential -AccessKey "YOUR_ACCESS_KEY" -SecretKey "YOUR_SECRET_KEY" -StoreAs default
   
   # Or use AWS CLI
   aws configure
   ```

3. **PowerShell 7+** (recommended for best performance)
   - Download from: https://github.com/PowerShell/PowerShell/releases

## Quick Start

### Option 1: Interactive Mode (Easiest)

```powershell
# Basic search
./Run-Search.ps1

# Advanced search with S3 Select
./Run-Search.ps1 -UseAdvanced
```

Just answer the prompts for bucket name, prefix, search string, and date.

### Option 2: Direct Command Line

**Standard Search:**
```powershell
./Search-S3JsonFiles.ps1 `
    -BucketName "my-bucket" `
    -Prefix "data/" `
    -SearchString "error_code_123" `
    -TargetDate "2025-10-18"
```

**Advanced Search with S3 Select:**
```powershell
./Search-S3JsonFiles-Advanced.ps1 `
    -BucketName "my-bucket" `
    -Prefix "data/logs/" `
    -SearchString "error_code_123" `
    -TargetDate "2025-10-18" `
    -Region "us-west-1" `
    -MaxParallel 20
```

**Search and download matching files:**
```powershell
./Search-S3JsonFiles.ps1 `
    -BucketName "my-bucket" `
    -Prefix "data/" `
    -SearchString "error_code_123" `
    -TargetDate "2025-10-18" `
    -DownloadMatches
```

**Search for two strings (both must be present):**
```powershell
./Search-S3JsonFiles.ps1 `
    -BucketName "my-bucket" `
    -Prefix "data/" `
    -SearchString "error" `
    -SearchString2 "timeout" `
    -TargetDate "2025-10-18"
```

**Search with date range:**
```powershell
./Search-S3JsonFiles.ps1 `
    -BucketName "my-bucket" `
    -Prefix "data/" `
    -SearchString "error_code_123" `
    -StartDate "2025-10-15" `
    -EndDate "2025-10-20"
```

**Search in specific JSON field:**
```powershell
./Search-S3JsonFiles-Advanced.ps1 `
    -BucketName "my-bucket" `
    -Prefix "data/" `
    -SearchString "timeout" `
    -TargetDate "2025-10-18" `
    -JsonPath "s.errorMessage"
```

## Scripts Overview

### 1. Search-S3JsonFiles.ps1 (Standard)
**Best for:** General use, works with any JSON structure

**How it works:**
1. Lists all S3 objects with the specified prefix
2. Filters objects by LastModified date (October 18, 2025)
3. Downloads and searches matching files in parallel
4. Returns all files containing the search string

**Pros:** Reliable, works with any JSON format
**Cons:** Downloads all candidate files (more data transfer)

### 2. Search-S3JsonFiles-Advanced.ps1 (Advanced)
**Best for:** Large datasets, well-formed JSON

**How it works:**
1. Lists and filters S3 objects by date
2. Uses AWS S3 Select to search server-side (no download needed)
3. Falls back to download method if S3 Select fails
4. Returns matching files

**Pros:** Much faster, minimal data transfer, lower cost
**Cons:** Requires properly formatted JSON (one object per file or JSONL)

### 3. Run-Search.ps1 (Wrapper)
Interactive wrapper that guides you through the search process with prompts.

## Performance Optimization

### For 100,000s of files:

1. **Use date filtering** - Reduces candidates from hundreds of thousands to potentially dozens/hundreds
2. **Increase parallelism** - Adjust `-MaxParallel` based on your machine:
   - 10-20 for local machines
   - 50-100 for EC2 instances with good network
3. **Use Advanced script** - S3 Select can be 10-100x faster
4. **Run from EC2** - If possible, run from EC2 in same region as bucket for faster network

### Estimated Performance:
- **100,000 total files** → ~100-500 files after date filter
- **Standard script**: ~2-5 minutes (depending on file sizes)
- **Advanced script**: ~30 seconds - 2 minutes

## Parameters Reference

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| BucketName | Yes | S3 bucket name | - |
| Prefix | Yes | Directory path in bucket | - |
| SearchString | Yes | Text to search for | - |
| SearchString2 | No | Second string (both must be present) | - |
| TargetDate | No* | Single date (yyyy-MM-dd) | - |
| StartDate | No* | Start of date range (yyyy-MM-dd) | - |
| EndDate | No* | End of date range (yyyy-MM-dd) | - |
| Region | No | AWS region | us-west-1 |
| MaxParallel | No | Parallel thread count | 10/20 |
| DownloadMatches | No | Download matching files locally | false |
| JsonPath | No | Specific JSON field (Advanced only) | - |
| UseS3Select | No | Enable S3 Select (Advanced only) | true |

\* Must specify either `TargetDate` (single day) OR `StartDate`/`EndDate` (range). `StartDate` and `EndDate` must be used together.

## Output

The tool provides:

1. **Console output** - Real-time progress and results
2. **CSV file** - `search_results_YYYYMMDD_HHMMSS.csv` with:
   - File key (full S3 path)
   - File size
   - Last modified timestamp
3. **Downloaded files** (if `-DownloadMatches` used) - Saved to `downloads_YYYYMMDD_HHMMSS/` folder
   - Files preserve their S3 directory structure
   - Ready for immediate use/analysis
4. **Download commands** - Ready-to-paste AWS CLI commands for manual retrieval

## Examples

### Example 1: Find and download error logs from specific date
```powershell
./Search-S3JsonFiles.ps1 `
    -BucketName "app-logs" `
    -Prefix "production/2025/10/" `
    -SearchString "OutOfMemoryException" `
    -TargetDate "2025-10-18" `
    -DownloadMatches
```

### Example 2: Search for user ID in transaction logs with date range
```powershell
./Search-S3JsonFiles-Advanced.ps1 `
    -BucketName "transactions" `
    -Prefix "payments/" `
    -SearchString "user-12345" `
    -StartDate "2025-10-15" `
    -EndDate "2025-10-20" `
    -JsonPath "s.userId" `
    -DownloadMatches
```

### Example 3: Find files with multiple strings (AND logic)
```powershell
./Search-S3JsonFiles.ps1 `
    -BucketName "app-logs" `
    -Prefix "errors/" `
    -SearchString "timeout" `
    -SearchString2 "database" `
    -TargetDate "2025-10-18"
```

### Example 4: Search date range for configuration issues
```powershell
./Search-S3JsonFiles.ps1 `
    -BucketName "config-backups" `
    -Prefix "configs/" `
    -SearchString "database.connection.timeout" `
    -StartDate "2025-10-01" `
    -EndDate "2025-10-31" `
    -MaxParallel 15
```

## Troubleshooting

### "Access Denied" errors
- Ensure IAM permissions include: `s3:ListBucket`, `s3:GetObject`
- For Advanced script, also need: `s3:SelectObjectContent`

### Slow performance
- Increase `-MaxParallel` parameter
- Use Advanced script with S3 Select
- Run from EC2 in same region as bucket
- Check if files are actually on the target date

### S3 Select failures
- S3 Select requires valid JSON format
- Falls back to standard download automatically
- Use `-UseS3Select $false` to disable completely

### Out of memory
- Reduce `-MaxParallel`
- Process in smaller date ranges
- Use Advanced script which doesn't store full content

## Cost Considerations

**Standard Script:**
- LIST requests: ~$0.005 per 1,000 requests
- GET requests: ~$0.0004 per 1,000 requests
- Data transfer: Varies by region

**Advanced Script (S3 Select):**
- SELECT requests: ~$0.002 per 1,000 requests
- Data scanned: ~$0.002 per GB scanned
- Data returned: ~$0.0007 per GB returned
- Usually cheaper for large files!

## Tips

1. **Be specific with prefixes** - Narrow down the search space
2. **Use exact dates** - Don't search multiple days if not needed
3. **Test with small datasets first** - Verify search string is correct
4. **Save your CSV results** - You might need to reference them later
5. **Check timezones** - S3 LastModified is in UTC

## License

MIT License - Feel free to modify and use as needed.

## Support

For issues or questions:
1. Check AWS credentials are configured
2. Verify bucket and prefix exist
3. Confirm IAM permissions
4. Review error messages in output
