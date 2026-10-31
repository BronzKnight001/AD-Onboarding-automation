# Active Directory Onboarding & Offboarding Automation

Two enterprise-grade PowerShell scripts for handling new hires and leavers in Active Directory (`corp.local`), complete with automated logging, dry-run support, and audit trails.

File structure
ACtive-Directoryt-Automation-Lab
 CSvTemplate
   users.csv | Sample input template for the provisioning script |
Scripts
 Offboard-Users.ps1| Safely disables an account and relocates it to t
 
 Onboard-Users.ps1 | Reads the HR CSV, generates secure passwords, resolves naming collisions, and provisions AD accounts                     into department OUs|

README.md

## Prerequisites & Environment

- **OS:** Windows Server 2025 (Domain Controller)
- **Domain:** `corp.local`
- **Module:** RSAT Active Directory PowerShell Module (`Get-WindowsCapability -Online -Name Rsat.ActiveDirectory*` to check)
- **Required OUs:** Departmental OUs must exist under a parent container (`OU=IT,OU=CompanyUsers,DC=corp,DC=local`), and a quarantine OU must exist (`OU=DisabledUsers,DC=corp,DC=local`).
## The CSV Format

Columns are FirstName, LastName, Department, JobTitle:

FirstName,LastName,Department,JobTitle
Alice,Smith,IT,Systems Administrator
Bob,Jones,HR,HR Coordinator
Charlie,Brown,Sales,Account Executive

JobTitle is optional (defaults to "Employee"). The other three are required, and rows missing any of them are skipped with a warning.

## How to Run

### 1. Creating Users (Onboarding)
Always do a dry run first using -WhatIf:

.\Scripts\Onboard-Users.ps1 -CsvPath .\CsvTemplates\users.csv -WhatIf

Then run it live:

.\Scripts\Onboard-Users.ps1 -CsvPath .\CsvTemplates\users.csv

**Parameters:**
- `-CsvPath`: Path to the HR file (default C:\Scripts\users.csv)
- `-Domain`: Used for the UPN suffix (default corp.local)
- `-BaseOU`: Parent OU that holds the department OUs
- `-LogDir`: Where logs go (default C:\Logs)

**Usernames & Passwords:**
- **Usernames** are first initial + last name, lowercase (e.g., Alice Smith becomes asmith). If taken, it tries asmith1, asmith2, etc.
- **Passwords** are random and comply with complexity rules. Users must change them at first logon. Temporary passwords are saved to prov_passwords_<timestamp>.csv in the log folder so you can distribute them.

Each run produces up to three files in LogDir:
- `prov_<timestamp>.log`: Full execution transcript.
- `prov_passwords_<timestamp>.csv`: Usernames and temporary passwords.
- `prov_errors_<timestamp>.csv`: Rows that failed, with the reason (only created if errors occur).

### 2. Offboarding Terminated Users
To offboard a single user:

.\Scripts\Offboard-Users.ps1 -TargetUser asmith -WhatIf
.\Scripts\Offboard-Users.ps1 -TargetUser asmith

To offboard several users at once from a text file (one username per line):

Get-Content .\leavers.txt | .\Scripts\Offboard-Users.ps1

## Limitations & Caveats

- **Scope:** Focuses strictly on core account lifecycle management (creation, attributes, disabling, and moving). Does not configure group memberships, mailboxes, or licenses.
- **Name Collisions:** Appends sequential numbers for identical names (jsmith, jsmith1), but does not perform duplicate-person cross-checks if the same person is submitted twice in a single feed.
- **Accented Characters:** Strips non-a-z characters during standard username generation.
- **Environment Testing:** Recommended to test in a lab environment before running against production schemas.
