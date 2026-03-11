# Background process that listens for sleep events and turns off the TV.
# Uses PowerModeChanged which fires *before* the system actually suspends,
# giving us time to complete the HTTP request.

. "$PSScriptRoot\config.ps1"
$TvApiUrl = "$TvApiOrigin/tv/off"

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
        try {
            Write-Log "Sending POST to $TvApiUrl ..."
            $body = @{ source = $TvSourceName } | ConvertTo-Json
            Invoke-RestMethod -Uri $TvApiUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 5
            Write-Log "TV API responded successfully."
        } catch {
            Write-Log "ERROR calling TV API: $_"
        }
        $AmpStateFile = Join-Path $PSScriptRoot ".amp-on"
        if (Test-Path $AmpStateFile) {
            Remove-Item $AmpStateFile -Force
            $AmpApiUrl = "$TvApiOrigin/amp/off"
            try {
                Write-Log "Sending POST to $AmpApiUrl ..."
                Invoke-RestMethod -Uri $AmpApiUrl -Method Post -TimeoutSec 5
                Write-Log "Amp API responded successfully."
            } catch {
                Write-Log "ERROR calling Amp API: $_"
            }
        } else {
            Write-Log "Amp was not turned on by wake script. Skipping amp off."
        }
    }
}
