# Background process that listens for sleep events and turns off the TV.
# Uses PowerModeChanged which fires *before* the system actually suspends,
# giving us time to complete the HTTP request.

. "$PSScriptRoot\config.ps1"
$TvApiUrl = "$TvApiOrigin/tv/off"
$lastOff = [DateTime]::MinValue
$cooldownSeconds = 30

Register-ObjectEvent -InputObject ([Microsoft.Win32.SystemEvents]) -EventName "PowerModeChanged" -SourceIdentifier "SleepWatch" | Out-Null

while ($true) {
    $ev = Wait-Event -SourceIdentifier "SleepWatch"
    Remove-Event -EventIdentifier $ev.EventIdentifier
    if ($ev.SourceEventArgs.Mode -eq [Microsoft.Win32.PowerModes]::Suspend) {
        if (((Get-Date) - $lastOff).TotalSeconds -lt $cooldownSeconds) {
            continue
        }
        try {
            Invoke-RestMethod -Uri $TvApiUrl -Method Post -TimeoutSec 5
            $lastOff = Get-Date
        } catch {
            # Nothing useful we can do here
        }
    }
}
