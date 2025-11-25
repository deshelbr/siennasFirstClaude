# IT Manager Guide: S3 JSON File Search Tool

## Executive Summary

The S3 JSON File Search Tool is a PowerShell-based solution that enables users to efficiently search through large volumes of JSON files stored in AWS S3 buckets. The tool is designed for scenarios where organizations need to locate specific data within hundreds of thousands of files, such as finding error logs, transaction records, or configuration data from a specific date.

**Key Benefits:**
- Reduces search time from hours to minutes through intelligent date filtering and parallel processing
- Minimizes AWS data transfer costs using server-side S3 Select queries
- Provides audit trail through CSV export of search results
- Requires no server infrastructure - runs directly on user workstations

---

## 1. What the Solution Does

### Primary Functionality

This tool allows authorized users to:

1. **Search JSON files in AWS S3 buckets** by filtering files created on a specific date
2. **Perform content searches** across thousands of files simultaneously using parallel processing
3. **Export results** to CSV format with file metadata (location, size, modification date)
4. **Generate download commands** for easy retrieval of matching files

### Use Cases

Common scenarios where this tool provides value:

- **Log Analysis**: Finding error logs or specific events from a particular date
- **Compliance & Auditing**: Locating transaction records for audit purposes
- **Troubleshooting**: Searching configuration files or diagnostic data
- **Data Discovery**: Identifying files containing specific identifiers (user IDs, order numbers, etc.)

### Available Search Methods

The solution provides two search implementations:

| Method | Description | Best For |
|--------|-------------|----------|
| **Standard Search** | Downloads files and searches locally | Reliable operation with any JSON format |
| **Advanced Search** | Uses AWS S3 Select for server-side filtering | Large datasets where minimizing data transfer is critical |

---

## 2. How the Solution Works

### Architecture Overview

The tool operates in three distinct phases:

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Date Filtering                                     │
│ • Lists all objects in specified S3 prefix                  │
│ • Filters by LastModified timestamp (UTC)                   │
│ • Identifies only .json files matching target date          │
└─────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Parallel Content Search                            │
│ • Distributes filtered files across parallel threads        │
│ • Standard: Downloads and searches file content             │
│ • Advanced: Uses S3 Select for server-side queries          │
│ • Tracks matching files in concurrent data structure        │
└─────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Results & Export                                   │
│ • Displays matching files with metadata                     │
│ • Exports results to timestamped CSV file                   │
│ • Generates AWS CLI download commands                       │
└─────────────────────────────────────────────────────────────┘
```

### Performance Characteristics

**Standard Search Method:**
- Processing time: 2-5 minutes for ~500 files (post date-filter)
- Network usage: Downloads all candidate files
- Parallelism: Configurable (default 10 concurrent threads)
- Reliability: High - works with any valid JSON

**Advanced Search Method (S3 Select):**
- Processing time: 30 seconds - 2 minutes for ~500 files
- Network usage: Minimal - queries executed server-side
- Parallelism: Configurable (default 20 concurrent threads)
- Reliability: Requires well-formed JSON; auto-fallback to download on failures

### Data Flow & Security

1. **Authentication**: Uses AWS credentials stored locally or via AWS credential chain
2. **Execution**: Entirely client-side - no intermediate servers or data storage
3. **Temporary Files**: Standard method creates temporary files during download (auto-deleted)
4. **Results Storage**: CSV output stored locally on user workstation

---

## 3. Required Windows/Microsoft User Permissions

### Windows Operating System Requirements

| Component | Requirement | Details |
|-----------|-------------|---------|
| **Operating System** | Windows 10/11 or Windows Server 2016+ | Any modern Windows with PowerShell support |
| **PowerShell Version** | PowerShell 5.1+ (PowerShell 7+ recommended) | Included in modern Windows; v7+ provides better performance |
| **Execution Policy** | RemoteSigned or Unrestricted | Required to run downloaded scripts |

### User Account Permissions

Users require the following Windows permissions:

#### 1. PowerShell Module Installation
```
Permission Required: Install PowerShell modules in user scope
Location: $HOME\Documents\PowerShell\Modules (user scope)
Alternative: System-wide installation requires local Administrator rights
```

**Recommended Approach for Corporate Environments:**
- Allow users to install modules with `-Scope CurrentUser` parameter
- **OR** Pre-install AWS.Tools.S3 module system-wide via Group Policy/SCCM

#### 2. PowerShell Script Execution

**Option A: User-level Execution Policy (Recommended)**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
- No administrator rights required
- Allows locally created scripts and signed remote scripts

**Option B: System-level Execution Policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```
- Requires local Administrator rights
- Can be deployed via Group Policy

#### 3. File System Permissions

| Location | Access Required | Purpose |
|----------|----------------|---------|
| Script directory | Read, Execute | Run PowerShell scripts |
| User TEMP folder | Read, Write, Delete | Standard method creates temporary downloaded files |
| Current directory | Write | Create CSV output files |
| PowerShell module path | Write (if user-scope install) | Install AWS.Tools modules |

#### 4. Network Connectivity

- **Outbound HTTPS (443)**: Access to AWS API endpoints (*.amazonaws.com)
- **Outbound HTTPS (443)**: Access to PowerShell Gallery (www.powershellgallery.com) for module installation
- **No inbound ports required**

### Corporate Environment Deployment Options

#### Option 1: Self-Service Installation (Least Privilege)
- Users run Setup.ps1 with standard user rights
- Modules installed to user profile ($HOME)
- Execution policy set at CurrentUser scope
- **Advantage**: No IT involvement needed after initial script deployment

#### Option 2: Managed Deployment (Enterprise Standard)
- IT pre-installs AWS.Tools.S3 module system-wide
- IT configures execution policy via Group Policy
- Users run scripts with standard user credentials
- **Advantage**: Centralized control and standardization

#### Option 3: Shared Credentials (Team Use)
- IT configures shared AWS credentials profile
- Scripts deployed to shared network location (read-only)
- Users execute from network share
- **Advantage**: Centralized credential management

---

## 4. Required AWS Permissions

### IAM Policy Overview

Users require an IAM policy granting specific S3 permissions. The required permissions vary based on the search method used.

### Minimum Required Permissions

#### Standard Search Method

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3JsonSearchStandard",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::bucket-name",
        "arn:aws:s3:::bucket-name/prefix/*"
      ]
    }
  ]
}
```

#### Advanced Search Method (with S3 Select)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3JsonSearchAdvanced",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:SelectObjectContent"
      ],
      "Resource": [
        "arn:aws:s3:::bucket-name",
        "arn:aws:s3:::bucket-name/prefix/*"
      ]
    }
  ]
}
```

### Permission Details

| Permission | Required For | Risk Level | Notes |
|------------|-------------|------------|-------|
| **s3:ListBucket** | Listing objects, date filtering | Low | Read-only; allows viewing file names and metadata |
| **s3:GetObject** | Downloading file content | Medium | Read-only; allows downloading file contents |
| **s3:SelectObjectContent** | S3 Select queries (Advanced mode) | Low | Read-only; executes server-side queries without download |

### Recommended IAM Policy Restrictions

#### 1. Bucket-Level Restrictions
Limit access to specific buckets only:

```json
"Resource": [
  "arn:aws:s3:::production-logs",
  "arn:aws:s3:::production-logs/*",
  "arn:aws:s3:::audit-data",
  "arn:aws:s3:::audit-data/*"
]
```

#### 2. Prefix-Level Restrictions
Restrict access to specific folders within buckets:

```json
"Resource": [
  "arn:aws:s3:::company-data/public-logs/*",
  "arn:aws:s3:::company-data/team-data/*"
]
```

#### 3. Condition-Based Restrictions

**Require MFA for access:**
```json
"Condition": {
  "Bool": {
    "aws:MultiFactorAuthPresent": "true"
  }
}
```

**Restrict to corporate IP ranges:**
```json
"Condition": {
  "IpAddress": {
    "aws:SourceIp": [
      "203.0.113.0/24",
      "198.51.100.0/24"
    ]
  }
}
```

**Time-based restrictions:**
```json
"Condition": {
  "DateGreaterThan": {"aws:CurrentTime": "2025-01-01T00:00:00Z"},
  "DateLessThan": {"aws:CurrentTime": "2025-12-31T23:59:59Z"}
}
```

### AWS Credential Configuration Options

#### Option 1: IAM User with Access Keys (Development/Individual)
```powershell
Set-AWSCredential -AccessKey "AKIA..." -SecretKey "..." -StoreAs default
```
- **Use Case**: Individual users, development environments
- **Security**: Credentials stored in user profile (encrypted by Windows)
- **Rotation**: Manual key rotation required

#### Option 2: IAM Roles with EC2 Instance Profile (Production)
- Users run scripts on EC2 instances with attached IAM role
- **Use Case**: Production operations, scheduled searches
- **Security**: No long-term credentials; automatic credential rotation
- **Advantage**: Centralized permission management

#### Option 3: AWS SSO / IAM Identity Center (Enterprise)
```powershell
# Users authenticate via SSO
aws sso login --profile production
```
- **Use Case**: Enterprise environments with centralized identity management
- **Security**: Leverages existing corporate authentication (AD/Okta/etc.)
- **Advantage**: No local credential storage; session-based access

#### Option 4: Assumed Roles (Cross-Account)
```powershell
# Assume role in different account
$credentials = Use-STSRole -RoleArn "arn:aws:iam::123456789:role/S3SearchRole" -RoleSessionName "search-session"
```
- **Use Case**: Cross-account access, auditor access
- **Security**: Temporary credentials with configurable session duration
- **Advantage**: Granular, time-limited access grants

### Recommended IAM Setup for Corporate Environments

#### 1. Create Dedicated IAM Group
```
Group Name: S3-JSON-Search-Users
Attached Policies: S3JsonSearch-Policy (custom policy above)
```

#### 2. Assign Users to Group
- Add users who require search capability
- Leverage existing AD/SSO integration for user management

#### 3. Enable CloudTrail Logging
Monitor all search operations:
- S3 data events for GetObject and SelectObjectContent
- Log retention for compliance requirements
- Alert on anomalous access patterns

#### 4. Implement Least Privilege
- Start with minimal permissions (specific buckets/prefixes)
- Expand access based on business justification
- Regular access reviews (quarterly recommended)

---

## 5. Security Considerations

### Data Security

| Aspect | Implementation | Risk Mitigation |
|--------|---------------|-----------------|
| **Data in Transit** | HTTPS/TLS to AWS APIs | AWS SDK enforces encryption |
| **Data at Rest** | CSV results on local workstation | User responsible for file encryption/deletion |
| **Credential Storage** | Windows Credential Manager (encrypted) | OS-level protection; supports credential rotation |
| **Audit Logging** | AWS CloudTrail logs all API calls | Enables detection of unauthorized access |

### Operational Security

**Recommended Security Measures:**

1. **Credential Management**
   - Enforce regular credential rotation (90 days)
   - Use IAM roles instead of access keys where possible
   - Enable MFA for sensitive S3 buckets

2. **Access Control**
   - Apply principle of least privilege
   - Restrict bucket/prefix access to business need
   - Use IAM conditions for IP/time restrictions

3. **Monitoring & Auditing**
   - Enable S3 access logging
   - Configure CloudTrail for API activity tracking
   - Set up alerts for bulk downloads or unusual patterns

4. **Data Classification**
   - Clearly label S3 buckets by sensitivity level
   - Restrict tool usage to non-PII data where possible
   - Implement DLP policies for downloaded CSV results

---

## 6. Installation & Deployment

### Automated Setup Process

The solution includes a Setup.ps1 script that automates installation:

1. Checks PowerShell version
2. Installs AWS.Tools.S3 module (if not present)
3. Configures AWS credentials (if not present)
4. Validates credential functionality

**User Execution:**
```powershell
.\Setup.ps1
```

### Manual Deployment Steps

If automated setup is restricted, IT can perform manual deployment:

#### Step 1: Install PowerShell Module (System-Wide)
```powershell
# Run as Administrator
Install-Module -Name AWS.Tools.S3 -Force -Scope AllUsers
```

#### Step 2: Configure Execution Policy (via Group Policy)
```
Computer Configuration > Policies > Administrative Templates >
Windows Components > Windows PowerShell > Turn on Script Execution
Setting: Allow local scripts and remote signed scripts
```

#### Step 3: Deploy Scripts
```
Recommended Location: C:\Program Files\S3JsonSearch\
Permissions: Read & Execute for authorized users
```

#### Step 4: Configure AWS Credentials
- Deploy via AWS SSO configuration
- OR distribute IAM credentials securely via existing credential management system

---

## 7. Cost Analysis

### AWS Service Costs

Based on searching 100,000 total files, filtered to 500 files by date:

#### Standard Search Method
```
LIST Requests:    100 requests × $0.005/1000  = $0.0005
GET Requests:     500 requests × $0.0004/1000 = $0.0002
Data Transfer:    ~50MB × $0.09/GB           = $0.0045
-----------------------------------------------------------
Total Cost per Search:                        ~$0.005
```

#### Advanced Search Method (S3 Select)
```
LIST Requests:    100 requests × $0.005/1000  = $0.0005
SELECT Requests:  500 requests × $0.002/1000  = $0.001
Data Scanned:     50MB × $0.002/GB            = $0.0001
Data Returned:    1MB × $0.0007/GB            = $0.00000007
-----------------------------------------------------------
Total Cost per Search:                        ~$0.002
```

**Estimated Annual Cost (100 searches/month):**
- Standard Method: ~$6/year
- Advanced Method: ~$2.40/year

### Total Cost of Ownership

| Component | One-Time Cost | Recurring Cost |
|-----------|--------------|----------------|
| Software licensing | $0 (open source) | $0 |
| User training | 1 hour per user | Minimal |
| IT setup/deployment | 2-4 hours | 0.5 hours/quarter (maintenance) |
| AWS costs | $0 | $2-6/year per active user |
| Infrastructure | $0 (client-side) | $0 |

**Total TCO**: Negligible - primarily IT time investment for initial setup

---

## 8. Support & Troubleshooting

### Common Issues & Resolutions

#### Issue: "Access Denied" Errors
**Cause**: Insufficient IAM permissions
**Resolution**:
1. Verify IAM policy includes s3:ListBucket and s3:GetObject
2. Check bucket policy doesn't deny access
3. Validate credentials are configured: `Get-AWSCredential -ProfileName default`

#### Issue: Slow Performance
**Cause**: Network latency or too many files after date filter
**Resolution**:
1. Increase MaxParallel parameter: `-MaxParallel 20`
2. Use Advanced script with S3 Select
3. Run from EC2 instance in same AWS region as bucket
4. Verify date filter is correctly narrowing file set

#### Issue: S3 Select Failures
**Cause**: Malformed JSON files
**Resolution**:
- Tool automatically falls back to standard download method
- Use `-UseS3Select $false` to disable S3 Select entirely
- Ensure JSON files are well-formed (one object per file)

#### Issue: Out of Memory Errors
**Cause**: Too many parallel operations
**Resolution**:
- Reduce `-MaxParallel` parameter: `-MaxParallel 5`
- Process smaller date ranges
- Use Advanced script (lower memory footprint)

### Escalation Path

1. **Level 1**: User documentation (README.md)
2. **Level 2**: IT helpdesk (verify credentials and permissions)
3. **Level 3**: AWS support (S3 API or service issues)
4. **Level 4**: Solution maintainer (script bugs or feature requests)

---

## 9. Compliance & Governance

### Audit Capabilities

The solution provides audit trails through multiple mechanisms:

1. **AWS CloudTrail**: Logs all S3 API calls (ListBucket, GetObject, SelectObjectContent)
2. **CSV Export**: Timestamped results provide record of searched files
3. **Script Logging**: Console output can be captured via transcript:
   ```powershell
   Start-Transcript -Path "search-audit-$(Get-Date -Format 'yyyyMMdd').log"
   .\Run-Search.ps1
   Stop-Transcript
   ```

### Compliance Considerations

| Regulation | Compliance Aspect | Implementation |
|------------|------------------|----------------|
| **GDPR** | Data access logging | CloudTrail enabled; 90-day retention minimum |
| **SOX** | Audit trail of data access | CloudTrail + CSV exports provide evidence |
| **HIPAA** | Access controls & encryption | IAM policies + TLS encryption in transit |
| **PCI-DSS** | Least privilege access | Restrictive IAM policies; regular access reviews |

### Data Retention

- **CloudTrail Logs**: Recommend 1-year retention for compliance
- **CSV Results**: User responsibility; suggest 90-day local retention
- **Script Access Logs**: Archive for compliance period (typically 7 years for financial data)

---

## 10. Frequently Asked Questions

### Functional Questions

**Q: Can this search non-JSON files?**
A: No, the tool is specifically designed for JSON files. Files must have .json extension.

**Q: Does it support compressed files (gzip)?**
A: Standard method: No. Advanced method: S3 Select supports gzip if configured. Requires modification to InputSerialization parameter.

**Q: Can I search multiple buckets simultaneously?**
A: Not in a single execution. Run separate searches per bucket.

**Q: How accurate is the date filtering?**
A: Highly accurate. Uses S3 LastModified timestamp (UTC). Note: This is modification time, not creation time.

### Security Questions

**Q: Is this tool safe for production use?**
A: Yes, if properly configured. It's read-only and doesn't modify S3 data. Follow least-privilege IAM policies.

**Q: Where are AWS credentials stored?**
A: In Windows Credential Manager (encrypted) at user profile level. Alternatively, can use IAM roles (no stored credentials).

**Q: Can users download files?**
A: Standard method downloads temporarily but auto-deletes. Tool provides AWS CLI commands for intentional downloads, which require same s3:GetObject permission.

**Q: Is network traffic encrypted?**
A: Yes, all AWS API calls use HTTPS/TLS encryption.

### Operational Questions

**Q: What's the maximum number of files it can handle?**
A: Tested with 100,000+ files. Date filtering typically reduces to hundreds. Practical limit depends on available memory and network.

**Q: Can this be automated/scheduled?**
A: Yes, can be called from scheduled tasks or automation platforms (Jenkins, etc.) by providing parameters non-interactively.

**Q: Does it require internet access?**
A: Yes, requires outbound HTTPS to AWS endpoints. Can work via corporate proxy if AWS PowerShell module is configured for proxy.

---

## 11. Recommendations for IT Managers

### Implementation Checklist

- [ ] **Review IAM Policy**: Ensure least-privilege access to only required buckets
- [ ] **Enable CloudTrail**: Log all S3 data events for audit trail
- [ ] **Configure S3 Access Logging**: Track bucket-level access patterns
- [ ] **Set Up Alerts**: Notify on unusual access patterns (e.g., >1000 GetObject calls/hour)
- [ ] **Document Approved Use Cases**: Define when tool usage is appropriate
- [ ] **User Training**: Brief users on proper usage and data handling
- [ ] **Credential Rotation**: Establish 90-day rotation policy for IAM access keys
- [ ] **Regular Access Reviews**: Quarterly review of users with access
- [ ] **Test Disaster Recovery**: Verify backup procedures for CSV results if needed

### Best Practices

1. **Start Small**: Pilot with a single team/department before org-wide rollout
2. **Use IAM Roles**: Prefer roles over access keys for better security
3. **Implement MFA**: Require MFA for access to sensitive S3 buckets
4. **Monitor Costs**: Track AWS costs; set billing alerts if usage exceeds expectations
5. **Version Control Scripts**: Store approved versions in controlled repository
6. **Document Changes**: Maintain changelog for any script modifications
7. **Regular Updates**: Monitor for AWS PowerShell module updates

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Unauthorized data access | Low | High | IAM policies, MFA, CloudTrail monitoring |
| Credential compromise | Medium | High | Regular rotation, use of IAM roles, SSO |
| Data exfiltration via CSV | Medium | Medium | DLP policies, user training, access reviews |
| AWS cost overrun | Low | Low | Billing alerts, date-filtering reduces API calls |
| Script vulnerability | Low | Medium | Code review, controlled versioning |

---

## 12. Summary

The S3 JSON File Search Tool provides a secure, cost-effective solution for searching large volumes of JSON data stored in AWS S3. With minimal infrastructure requirements and read-only access patterns, it presents low operational risk when deployed with appropriate IAM policies and monitoring.

**Key Takeaways for IT Managers:**

✓ **Zero Infrastructure Cost**: Runs on user workstations; no servers required
✓ **Minimal AWS Cost**: ~$2-6/year per active user
✓ **Read-Only Operations**: Cannot modify or delete S3 data
✓ **Comprehensive Audit Trail**: CloudTrail + CSV exports for compliance
✓ **Flexible Deployment**: Self-service or IT-managed installation options
✓ **Granular Access Control**: IAM policies support bucket/prefix restrictions

**Approval Recommendation**: Approve for deployment with standard IAM least-privilege policies and CloudTrail monitoring enabled.

---

## Document Information

**Version**: 1.0
**Last Updated**: 2025-11-21
**Maintained By**: IT Infrastructure Team
**Review Cycle**: Quarterly

For questions or clarification, contact your IT Security or Cloud Infrastructure team.
