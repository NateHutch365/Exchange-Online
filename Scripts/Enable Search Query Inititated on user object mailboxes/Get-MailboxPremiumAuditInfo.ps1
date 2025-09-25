## Connect to Exchange Online
## Use following parameters to connect as guest -UserPrincipalName name@domain.com -DelegatedOrganization tenantname.onmicrosoft.com

Connect-ExchangeOnline

$auditPremiumEnabledMailboxes = $null
$auditPremiumEnabledMailboxes = (Get-Mailbox | where-object {$_.AuditOwner -contains 'SearchQueryInitiatedExchange' -or $_.AuditOwner -contains 'SearchQueryInitiatedSharePoint'} | select Name, AuditOwner | convertTo-Json)
If ($auditPremiumEnabledMailboxes -eq $null)
{
Write-Host "No mailboxes found with Premium Audits enabled" -ForegroundColor "Yellow"
}
Else
{
Write-Host "List of mailboxes with Premium Audits enabled:" -ForegroundColor "Yellow"
Write-Host $auditPremiumEnabledMailboxes
}