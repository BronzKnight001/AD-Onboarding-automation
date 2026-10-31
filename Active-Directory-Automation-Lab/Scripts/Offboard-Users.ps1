<#
Offboards AD users: disables the account, then moves it to the disabled OU.
Takes SamAccountNames from the pipeline, e.g.
    Get-Content leavers.txt | .\Offboard-User.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('SamAccountName')]
    [string]$TargetUser,

    [string]$DisabledOU = "OU=DisabledUsers,DC=corp,DC=local",
    [string]$LogDir     = "C:\Logs"
)

begin {
    $ErrorActionPreference = 'Stop'
    Import-Module ActiveDirectory

    if (-not (Test-Path $LogDir)) { New-Item $LogDir -ItemType Directory | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Start-Transcript -Path (Join-Path $LogDir "offboard_$stamp.log") | Out-Null

    # check the destination first so we never disable someone we can't move
    try {
        $null = Get-ADOrganizationalUnit -Identity $DisabledOU
    }
    catch {
        Stop-Transcript | Out-Null
        throw "Disabled OU not found: $DisabledOU"
    }

    $done   = 0
    $failed = 0
}

process {
    try {
        $user = Get-ADUser -Identity $TargetUser

        if ($PSCmdlet.ShouldProcess($TargetUser, "Disable and move to $DisabledOU")) {
            Disable-ADAccount -Identity $user
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $DisabledOU
            Write-Host "Offboarded $TargetUser" -ForegroundColor Green
            $done++
        }
    }
    catch {
        # if the move fails the account is already disabled, check the log
        Write-Warning "Problem with $TargetUser : $($_.Exception.Message)"
        $failed++
    }
}

end {
    Write-Host "$done offboarded, $failed failed." -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    if ($failed) { exit 1 }
}