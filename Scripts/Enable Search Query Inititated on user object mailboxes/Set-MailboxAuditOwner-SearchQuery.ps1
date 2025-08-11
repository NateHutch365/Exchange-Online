<# 
.SYNOPSIS
Ensures "SearchQueryInitiated" is included in AuditOwner for user mailboxes.

.EXAMPLES
# Dry run against a couple of users, write report to default timestamped file
.\Set-MailboxAuditOwner-SearchQuery.ps1 -Users user1@contoso.com,user2@contoso.com -WhatIf

# Apply changes to all user mailboxes, write report to a chosen path
.\Set-MailboxAuditOwner-SearchQuery.ps1 -ReportPath "C:\Temp\AuditOwner_Changes.txt"

# Apply changes only to listed users and save report
.\Set-MailboxAuditOwner-SearchQuery.ps1 -Users "user1@contoso.com","user2@contoso.com" -ReportPath "C:\Temp\AuditOwner_SelectedUsers.txt"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]] $Users,                  # Optional: target specific user mailboxes by UPN/Alias/DisplayName
    [string]   $ReportPath              # Optional: path to .txt report (changes only). Default = timestamped in current folder
)

begin {
    # Connect (assumes Exchange Online module is installed and available)
    try {
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            throw "ExchangeOnlineManagement module not found. Install-Module ExchangeOnlineManagement"
        }
        if (-not (Get-ConnectionInformation)) {
            Connect-ExchangeOnline -ShowBanner:$false | Out-Null
        }
    } catch {
        Write-Error "Failed to connect to Exchange Online: $_"
        break
    }

    $requiredAuditOps = @('SearchQueryInitiated')

    if (-not $ReportPath) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $ReportPath = Join-Path -Path (Get-Location) -ChildPath "AuditOwner_Changes_$stamp.txt"
    }

    # Initialise report
    "AuditOwner update report"                  | Out-File -FilePath $ReportPath -Encoding UTF8
    "Run at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')" | Add-Content -Path $ReportPath
    "WhatIf: $($PSCmdlet.ShouldProcess('x','y') -and $WhatIfPreference)" | Add-Content -Path $ReportPath
    "Targeting: $([string]::Join(', ', ($Users | ForEach-Object { $_ }) ) )" | Add-Content -Path $ReportPath
    "Required operation(s): $($requiredAuditOps -join ', ')" | Add-Content -Path $ReportPath
    "--------------------------------------------------------------------" | Add-Content -Path $ReportPath
}

process {
    # Resolve target mailboxes
    $mailboxes = @()
    if ($Users -and $Users.Count -gt 0) {
        foreach ($u in $Users) {
            $mbx = Get-Mailbox -Identity $u -ErrorAction SilentlyContinue | Where-Object { $_.RecipientTypeDetails -eq 'UserMailbox' }
            if ($null -eq $mbx) {
                $line = "NOT FOUND or not a UserMailbox: '$u'"
                Write-Warning $line
                Add-Content -Path $ReportPath -Value $line
            } else {
                $mailboxes += $mbx
            }
        }
    } else {
        # All user mailboxes for broad application
        $mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox
    }

    if (-not $mailboxes -or $mailboxes.Count -eq 0) {
        $msg = "No target user mailboxes found. Exiting."
        Write-Warning $msg
        Add-Content -Path $ReportPath -Value $msg
        return
    }

    foreach ($mailbox in $mailboxes) {
        $currentOps = @()
        if ($mailbox.AuditOwner) { $currentOps = @($mailbox.AuditOwner) }

        $missingOps = $requiredAuditOps | Where-Object { $_ -notin $currentOps }

        if ($missingOps.Count -gt 0) {
            $newOps = $currentOps + $missingOps

            $targetLabel = "$($mailbox.DisplayName) <$($mailbox.PrimarySmtpAddress)>"
            $before = if ($currentOps.Count) { $currentOps -join ', ' } else { '(none)' }
            $after  = $newOps -join ', '

            $preview = "UPDATE NEEDED: $targetLabel | Before: [$before] -> After: [$after]"
            Write-Host $preview -ForegroundColor Cyan
            Add-Content -Path $ReportPath -Value $preview

            if ($PSCmdlet.ShouldProcess($mailbox.Identity, "Set-Mailbox -AuditOwner '$($newOps -join ',')'")) {
                try {
                    Set-Mailbox -Identity $mailbox.Identity -AuditOwner $newOps -ErrorAction Stop
                    $ok = "SUCCESS: $targetLabel updated."
                    Write-Host $ok -ForegroundColor Green
                    Add-Content -Path $ReportPath -Value $ok
                }
                catch {
                    $err = "FAILED: $targetLabel | Error: $_"
                    Write-Host $err -ForegroundColor Red
                    Add-Content -Path $ReportPath -Value $err
                }
            } else {
                $skipped = "WHATIF: $targetLabel would be updated."
                Write-Host $skipped -ForegroundColor Yellow
                Add-Content -Path $ReportPath -Value $skipped
            }

            Add-Content -Path $ReportPath -Value ("-" * 68)
        }
        else {
            $msg = "NO CHANGE: $($mailbox.DisplayName) <$($mailbox.PrimarySmtpAddress)> already includes required ops."
            Write-Host $msg -ForegroundColor Yellow
            # We only export changes by request; comment in the next line if you also want no-change lines recorded
            # Add-Content -Path $ReportPath -Value $msg
        }
    }
}

end {
    Write-Host "Report written to: $ReportPath" -ForegroundColor Magenta
}
