# Sleep handling is now owned by tvmaster's observer model.
# This script is intentionally disabled, but kept around so existing
# scheduled tasks fail closed until they are deregistered.

. "$PSScriptRoot\config.ps1"
$LogFile = Join-Path $PSScriptRoot "on-sleep.log"
function Write-Log($msg) {
    if (-not $LogToFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts  $msg" | Out-File -Append -FilePath $LogFile
}
Write-Log "=== on-sleep.ps1 disabled; tvmaster observer handles sleep ==="
