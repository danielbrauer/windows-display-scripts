# Background process that listens for sleep events and turns off the TV.
# Uses PowerModeChanged which fires *before* the system actually suspends,
# giving us time to complete the HTTP request.

. "$PSScriptRoot\config.ps1"
$TvApiUrl = "$TvApiOrigin/tv/off"
$lastOff = [DateTime]::MinValue
$cooldownSeconds = 30

$LogFile = Join-Path $PSScriptRoot "on-sleep.log"
function Write-Log($msg) {
    if (-not $LogToFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts  $msg" | Out-File -Append -FilePath $LogFile
}
Write-Log "=== on-sleep.ps1 started ==="

Register-ObjectEvent -InputObject ([Microsoft.Win32.SystemEvents]) -EventName "PowerModeChanged" -SourceIdentifier "SleepWatch" | Out-Null

while ($true) {
    $ev = Wait-Event -SourceIdentifier "SleepWatch"
    Remove-Event -EventIdentifier $ev.EventIdentifier
    Write-Log "PowerModeChanged event: $($ev.SourceEventArgs.Mode)"
    if ($ev.SourceEventArgs.Mode -eq [Microsoft.Win32.PowerModes]::Suspend) {
        if (((Get-Date) - $lastOff).TotalSeconds -lt $cooldownSeconds) {
            Write-Log "Cooldown active, skipping."
            continue
        }
        try {
            Write-Log "Sending POST to $TvApiUrl ..."
            $body = @{ source = $TvSourceName } | ConvertTo-Json
            Invoke-RestMethod -Uri $TvApiUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 5
            $lastOff = Get-Date
            Write-Log "TV API responded successfully."
        } catch {
            Write-Log "ERROR calling TV API: $_"
        }
    }
}
