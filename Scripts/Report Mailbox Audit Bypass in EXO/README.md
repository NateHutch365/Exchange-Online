# Report-MailboxAuditBypass.ps1

A PowerShell script to inventory **Mailbox Audit Bypass** in Exchange Online, export a timestamped CSV report, and (optionally) create a full baseline of all principals checked. Useful for security reviews, SOX/ISO evidence, and ongoing monitoring.

---

## What it checks

* Queries `Get-MailboxAuditBypassAssociation` in Exchange Online.
* Reports *principals* (users/service accounts/guests/etc.) where **AuditBypassEnabled** is set.
* The bypass flag is on the *accessing account* (principal), not on a specific mailbox.

---

## Prerequisites

* PowerShell 7.x or Windows PowerShell 5.1
* Module: `ExchangeOnlineManagement`

  * Script installs it for the current user if missing.
* Permissions: ability to run `Get-MailboxAuditBypassAssociation` in your tenant (any EXO admin role with read access suffices; e.g., View-Only Recipients, Exchange Admin).
* Internet access to connect to Exchange Online.

---

## Parameters

```powershell
-OutputFolder <string>   # Default: ~/Documents/MailboxAuditBypassReports
-ExportAll               # Also export a full baseline of all objects
-OpenOnSave              # Open the generated CSV file(s) after export
```

---

## Quick start

```powershell
# 1) Connects if needed
# 2) Exports a CSV of only principals with bypass enabled (if any)
# 3) Writes to ~/Documents/MailboxAuditBypassReports by default

.\Report-MailboxAuditBypass.ps1
```

With options:

```powershell
# Choose a custom folder
.\Report-MailboxAuditBypass.ps1 -OutputFolder "C:\Reports\AuditBypass"

# Export full baseline (all principals) and open the files when done
.\Report-MailboxAuditBypass.ps1 -ExportAll -OpenOnSave
```

---

## Outputs

* **MailboxAuditBypass\_ENABLED\_yyyyMMdd-HHmmss.csv**

  * Only rows where `AuditBypassEnabled = True`.
  * Columns: `Identity, User, AuditBypassEnabled, WhenChanged, ExternalDirectoryObjectId`.
* **MailboxAuditBypass\_ALL\_yyyyMMdd-HHmmss.csv** *(when `-ExportAll` is used)*

  * Full dump of all principals returned by the cmdlet with the same columns.

Empty tenant? If no principals have bypass enabled, the script still writes an **empty ENABLED report** with headers for evidence.

---

## Typical results & scope

* `Get-MailboxAuditBypassAssociation` returns **all tracked principals** (members, guests, service accounts, etc.), not just mailbox owners.
* A zero count is normal in healthy tenants.

To focus on subsets, run these afterwards if you like:

```powershell
# Members only (exclude guests)
Get-MailboxAuditBypassAssociation -ResultSize Unlimited |
  Where-Object { $_.User -notlike "*#EXT#*" }

# Only principals that correspond to actual user/shared mailboxes
$mbxUPNs = (Get-ExoMailbox -ResultSize Unlimited).UserPrincipalName
Get-MailboxAuditBypassAssociation -ResultSize Unlimited |
  Where-Object { $_.User -in $mbxUPNs }
```

---

## Example: turn findings into an email alert

Add this after the export to email when any bypass is found:

```powershell
if ($enabled.Count -gt 0) {
  $body = @(
    "Mailbox Audit Bypass is ENABLED for $($enabled.Count) principal(s).",
    "Report: $enabledReportPath"
  ) -join "`n"
  Send-MailMessage -To "secops@contoso.com" -From "noreply@contoso.com" -Subject "Alert: Mailbox Audit Bypass" -Body $body -SmtpServer "smtp.contoso.com"
}
```

> Replace SMTP bits with your org’s preferred mail method.

---

## Scheduling (Windows Task Scheduler)

1. Save the script to a secure path, e.g. `C:\SecScripts\Report-MailboxAuditBypass.ps1`.
2. Create a task to run under a service account with EXO access.
3. **Action:** `powershell.exe` (or `pwsh.exe`)

   * **Arguments:**

     ```
     -NoProfile -ExecutionPolicy Bypass -File "C:\SecScripts\Report-MailboxAuditBypass.ps1" -ExportAll -OutputFolder "C:\Reports\Audit"
     ```
4. Configure the account to authenticate (e.g., app password/interactive sign-in as per policy). Consider using Managed Identity on an Automation Worker/Azure Automation Runbook instead of a server.

---

## CI/CD or evidence capture tip

* Commit the CSVs into a private repo or blob storage with immutable retention (where policy allows). The timestamped filenames make diffs and audits easy.

---

## Troubleshooting

**Error:** `object '\' couldn't be found ...`

* Cause: backslash used as a literal before the pipeline. Remove the `\` and use a normal `|` pipe.

**Cannot connect / stale session**

* Run `Disconnect-ExchangeOnline -Confirm:$false` then retry.

**Module not found**

* Script attempts to install `ExchangeOnlineManagement` for CurrentUser. If blocked by policy, pre‑install with admin rights.

**Empty results**

* This is good. It means no principals have audit bypass enabled. Use `-ExportAll` if you want the baseline snapshot as well.

---

## Security considerations

* Store output in a restricted location (least privilege).
* Review findings promptly—bypass should rarely be enabled and only for highly constrained diagnostic scenarios.
* Consider alerting and a CAB process before enabling/disabling bypass.

---

## Versioning

* v1.0 — Initial release (query, export, baseline, basic summary)
