# Monitor-SSHAwake.ps1
# Run as a scheduled task every 60 seconds

$awakeProcess = Get-Process -Name "PowerToys.Awake" -ErrorAction SilentlyContinue

# sshd spawns a child process per connection; the parent listener is always running
# So >1 sshd process means at least one active session
$sshdProcesses = @(Get-Process -Name sshd -ErrorAction SilentlyContinue)
$activeSessions = $sshdProcesses.Count -gt 1

if ($activeSessions -and -not $awakeProcess) {
    # First session detected, start Awake
    & "$env:LOCALAPPDATA\PowerToys\PowerToys.Awake.exe" `
        --use-pt-config false --display-on false --time-limit 0
    Write-EventLog -LogName Application -Source "SSH-Awake" -EventId 1 -Message "Awake activated: SSH session detected"
}
elseif (-not $activeSessions -and $awakeProcess) {
    # Last session gone, stop Awake
    Stop-Process -Name "PowerToys.Awake" -Force
    Write-EventLog -LogName Application -Source "SSH-Awake" -EventId 2 -Message "Awake deactivated: no SSH sessions"
}
