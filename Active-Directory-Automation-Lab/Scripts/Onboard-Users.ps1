<#
Creates AD accounts from the HR csv (Luis,Mojica Ochoa, Active Directory-lab ).
Failed rows get written to an errors csv so HR/service desk can fix them.
Run with -WhatIf first.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = "C:\Scripts\users.csv",
    [string]$Domain  = "corp.local",
    [string]$BaseOU  = "OU=CompanyUsers,DC=corp,DC=local",
    [string]$LogDir  = "C:\Logs"
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

if (-not (Test-Path $LogDir)) { New-Item $LogDir -ItemType Directory | Out-Null }

$stamp    = Get-Date -Format 'yyyyMMdd_HHmmss'
$errorCsv = Join-Path $LogDir "prov_errors_$stamp.csv"
$passCsv  = Join-Path $LogDir "prov_passwords_$stamp.csv"

Start-Transcript -Path (Join-Path $LogDir "prov_$stamp.log") | Out-Null

function New-TempPassword {
    $chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%'
    $bytes = New-Object byte[] 14
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    # prefix guarantees upper/lower/digit/symbol for the complexity policy
    'Aa1!' + (-join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] }))
}

$failed  = @()
$created = @()

try {
    $rows = Import-Csv $CsvPath

    foreach ($row in $rows) {
        if (-not $row.FirstName -or -not $row.LastName -or -not $row.Department) {
            Write-Warning "Skipping row, missing name or department: $($row.FirstName) $($row.LastName)"
            continue
        }

        $first = $row.FirstName.Trim()
        $last  = $row.LastName.Trim()
        $dept  = $row.Department.Trim()
        $title = if ($row.JobTitle) { $row.JobTitle.Trim() } else { "Employee" }

        # jsmith, jsmith1, jsmith2...
        $base = ($first.Substring(0,1) + ($last -replace '[^a-zA-Z]', '')).ToLower()
        $sam  = $base
        $i    = 1
        while (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
            $sam = "$base$i"
            $i++
        }

        $ou = "OU=$dept,$BaseOU"

        try {
            $deptEsc = $ou -replace "'", "''"
            if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$deptEsc'" -ErrorAction SilentlyContinue)) {
                throw "OU not found: $ou"
            }

            $pw = New-TempPassword

            if ($PSCmdlet.ShouldProcess($sam, "Create AD user in $ou")) {
                New-ADUser -Name "$first $last" `
                           -GivenName $first `
                           -Surname $last `
                           -SamAccountName $sam `
                           -UserPrincipalName "$sam@$Domain" `
                           -Path $ou `
                           -Title $title `
                           -Department $dept `
                           -AccountPassword (ConvertTo-SecureString $pw -AsPlainText -Force) `
                           -ChangePasswordAtLogon $true `
                           -Enabled $true

                Write-Host "Created $sam ($dept)" -ForegroundColor Green
                $created += [pscustomobject]@{ Sam = $sam; Name = "$first $last"; TempPassword = $pw }
            }
        }
        catch {
            Write-Warning "Failed on $first $last : $($_.Exception.Message)"
            $failed += [pscustomobject]@{
                FirstName  = $first
                LastName   = $last
                Department = $dept
                Error      = $_.Exception.Message
                Time       = Get-Date
            }
        }
    }

    if ($created.Count) { $created | Export-Csv $passCsv -NoTypeInformation }

    if ($failed.Count) {
        $failed | Export-Csv $errorCsv -NoTypeInformation
        Write-Host "$($created.Count) created, $($failed.Count) failed. See $errorCsv" -ForegroundColor Yellow
    }
    else {
        Write-Host "Done. $($created.Count) accounts created, no errors." -ForegroundColor Cyan
    }
}
finally {
    Stop-Transcript | Out-Null
}