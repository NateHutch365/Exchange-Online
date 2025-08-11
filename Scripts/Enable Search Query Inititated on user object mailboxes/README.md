# README: Ensure "SearchQueryInitiated" Audit Operation for User Mailboxes

## Overview

This PowerShell script connects to Exchange Online and ensures that the `SearchQueryInitiated` audit operation is enabled for the **AuditOwner** setting on user mailboxes. This audit operation records when a mailbox owner initiates a search, which is useful for security investigations and compliance.

The script:

* Connects to Exchange Online.
* Retrieves **UserMailbox** type mailboxes.
* Checks the `AuditOwner` property for the `SearchQueryInitiated` operation.
* Adds it if missing, while preserving existing operations.
* Outputs changes to the console and logs them to a `.txt` report file.
* Supports targeting specific mailboxes and performing dry-run tests with `-WhatIf`.

---

## Requirements

* **ExchangeOnlineManagement** PowerShell module installed.
* Sufficient permissions to run `Get-Mailbox` and `Set-Mailbox` in Exchange Online.
* PowerShell 5.1 or later / PowerShell 7+.

---

## Parameters

| Parameter     | Description                                                                                                     | Optional | Example                                       |
| ------------- | --------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------- |
| `-Users`      | List of user mailboxes to target (by UPN, alias, or display name). If omitted, all user mailboxes are targeted. | Yes      | `-Users user1@contoso.com,user2@contoso.com`  |
| `-ReportPath` | File path for the `.txt` change log. If omitted, a timestamped file is created in the current directory.        | Yes      | `-ReportPath "C:\Temp\AuditOwnerChanges.txt"` |
| `-WhatIf`     | Shows what changes would be made without applying them.                                                         | Yes      | `-WhatIf`                                     |

---

## Usage Examples

### 1. Dry-run against specific users

```powershell
.
Set-MailboxAuditOwner-SearchQuery.ps1 -Users user1@contoso.com,user2@contoso.com -WhatIf
```

### 2. Apply changes to all user mailboxes

```powershell
.
Set-MailboxAuditOwner-SearchQuery.ps1
```

### 3. Apply changes to specific users and save report to a custom location

```powershell
.
Set-MailboxAuditOwner-SearchQuery.ps1 -Users "user1@contoso.com","user2@contoso.com" -ReportPath "C:\Temp\AuditOwner_SelectedUsers.txt"
```

---

## Output

* Console output showing:

  * Mailboxes needing updates
  * Before/after `AuditOwner` values
  * Success or failure messages
* Text report containing all changes (and failed lookups).

---

## Notes

* The script **only** targets `UserMailbox` recipients when run without `-Users`.
* Existing `AuditOwner` operations are preserved when adding `SearchQueryInitiated`.
* The `-WhatIf` flag is highly recommended for first-time runs.
* For large tenants, runtime may be significant.

---

## Troubleshooting

* **Module not found**: Install the Exchange Online module with:

  ```powershell
  Install-Module ExchangeOnlineManagement
  ```
* **Authentication issues**: Ensure you have the appropriate Exchange Online admin roles assigned.
* **Audit not enabled**: If mailbox auditing is disabled, enable it first:

  ```powershell
  Set-Mailbox -Identity user@contoso.com -AuditEnabled $true
  ```
