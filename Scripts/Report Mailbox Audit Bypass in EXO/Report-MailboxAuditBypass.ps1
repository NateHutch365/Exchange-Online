<# 
.SYNOPSIS
  Report Mailbox Audit Bypass in Exchange Online and export CSV.
.DESCRIPTION
  Connects (if needed), queries Get-MailboxAuditBypassAssociation, 
  exports a CSV of objects with AuditBypassEnabled = $true. 
  Optionally exports a full baseline CSV of all objects.
.PARAMETER OutputFolder
  Folder to save reports. Defaults to ~/Documents/MailboxAuditBypassReports
.PARAMETER ExportAll
  Also export a full baseline (all objects) CSV alongside the enabled report.
.PARAMETER OpenOnSave
  Opens the report(s) after saving.
#>

param(
    [string]$OutputFolder = (Join-Path $HOME "Documents/MailboxAuditBypassReports"),
    [switch]$ExportAll,
    [switch]$OpenOnSave
)

# Ensure the Exchange Online module is available
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    try {
        Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to install ExchangeOnlineManagement: $($_.Exception.Message)"
        return
    }
}

# Import and connect (if needed)
Import-Module ExchangeOnlineManagement -ErrorAction Stop

# Only connect if not already connected
$alreadyConnected = (Get-ConnectionInformation | Where-Object { $_.Name -eq "ExchangeOnline" -and $_.State -eq "Connected" })
if (-not $alreadyConnected) {
    try {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    } catch {
        Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
        return
    }
}

# Create output folder
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$enabledReportPath = Join-Path $OutputFolder "MailboxAuditBypass_ENABLED_$timestamp.csv"
$allReportPath     = Join-Path $OutputFolder "MailboxAuditBypass_ALL_$timestamp.csv"

Write-Host "Querying mailbox audit bypass associations..." -ForegroundColor Cyan

# Pull the data
try {
    $all = Get-MailboxAuditBypassAssociation -ResultSize Unlimited |
           Select-Object Identity, User, AuditBypassEnabled, WhenChanged, ExternalDirectoryObjectId
} catch {
    Write-Error "Query failed: $($_.Exception.Message)"
    return
}

$enabled = $all | Where-Object { $_.AuditBypassEnabled -eq $true }

# Export results
if ($enabled.Count -gt 0) {
    $enabled | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $enabledReportPath
    Write-Host "Saved ENABLED report: $enabledReportPath" -ForegroundColor Green
    if ($OpenOnSave) { Invoke-Item $enabledReportPath }
} else {
    # Still write an empty file with headers so you have an artefact
    $null | Select-Object Identity, User, AuditBypassEnabled, WhenChanged, ExternalDirectoryObjectId |
        Export-Csv -NoTypeInformation -Encoding UTF8 -Path $enabledReportPath
    Write-Host "No accounts with audit bypass enabled. Empty report created: $enabledReportPath" -ForegroundColor Yellow
    if ($OpenOnSave) { Invoke-Item $enabledReportPath }
}

if ($ExportAll) {
    $all | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $allReportPath
    Write-Host "Saved FULL baseline report: $allReportPath" -ForegroundColor Green
    if ($OpenOnSave) { Invoke-Item $allReportPath }
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ("Total objects checked : {0}" -f $all.Count)
Write-Host ("Bypass ENABLED count  : {0}" -f $enabled.Count)

# Optional: flag non-zero in output for CI/monitoring pipelines
if ($enabled.Count -gt 0) {
    Write-Warning "One or more principals have Mailbox Audit Bypass ENABLED."
}
