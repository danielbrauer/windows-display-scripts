# Immediately disables Parsec and the virtual display.
# Stops the ParsecEnable monitor task if running.
# Triggered on-demand via the ParsecDisable scheduled task.

. "$PSScriptRoot\config.ps1"
$LogFile = Join-Path $PSScriptRoot "parsec.log"
function Write-Log($msg) {
    if (-not $LogToFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts  $msg" | Out-File -Append -FilePath $LogFile
}

$DeviceId = 'ROOT\DISPLAY\0000'

Write-Log "=== parsec-disable.ps1 started ==="

Stop-ScheduledTask -TaskName 'ParsecEnable' -ErrorAction SilentlyContinue
Write-Log "ParsecEnable task stopped"

Stop-Service Parsec -Force -ErrorAction SilentlyContinue
Write-Log "Parsec stopped"

Disable-PnpDevice -InstanceId $DeviceId -Confirm:$false -ErrorAction SilentlyContinue
Write-Log "VDD disabled"
