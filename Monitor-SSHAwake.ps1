# Background process that keeps the machine awake while SSH sessions are active.
# Uses WMI events to react to sshd process creation/deletion instead of polling.
# Runs as a logon-triggered scheduled task (like on-sleep.ps1).

. "$PSScriptRoot\config.ps1"
$LogFile = Join-Path $PSScriptRoot "monitor-ssh-awake.log"
function Write-Log($msg) {
    if (-not $LogToFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts  $msg" | Out-File -Append -FilePath $LogFile
}
Write-Log "=== Monitor-SSHAwake.ps1 started ==="

$AwakePath = "$env:LOCALAPPDATA\PowerToys\PowerToys.Awake.exe"

function Get-SSHSessionActive {
    # sshd spawns a child process per connection; the parent listener is always running.
    # So >1 sshd process means at least one active session.
    @(Get-Process -Name sshd -ErrorAction SilentlyContinue).Count -gt 1
}

function Start-Awake {
    if (Get-Process -Name "PowerToys.Awake" -ErrorAction SilentlyContinue) { return }
    Start-Process -FilePath $AwakePath -ArgumentList "--use-pt-config false --display-on false --time-limit 0"
    Write-Log "Awake activated: SSH session detected"
}

function Stop-Awake {
    if (-not (Get-Process -Name "PowerToys.Awake" -ErrorAction SilentlyContinue)) { return }
    Stop-Process -Name "PowerToys.Awake" -Force
    Write-Log "Awake deactivated: no SSH sessions"
}

# Set initial state
if (Get-SSHSessionActive) {
    Start-Awake
} else {
    Stop-Awake
}

# Watch for sshd process creation and deletion
Register-CimIndicationEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = 'sshd.exe'" -SourceIdentifier "SSHStart" | Out-Null
Register-CimIndicationEvent -Query "SELECT * FROM __InstanceDeletionEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = 'sshd.exe'" -SourceIdentifier "SSHStop" | Out-Null

# Remove Claude desktop shortcut if it exists
$claudeShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Claude.lnk"
if (Test-Path $claudeShortcut) {
    Remove-Item $claudeShortcut -Force
}

while ($true) {
    $ev = Wait-Event -SourceIdentifier "SSH*"
    Remove-Event -EventIdentifier $ev.EventIdentifier

    # Brief pause so process list reflects the change
    Start-Sleep -Milliseconds 500

    $active = Get-SSHSessionActive
    Write-Log "sshd event ($($ev.SourceIdentifier)): activeSessions=$active"

    if ($active) {
        Start-Awake
    } else {
        Stop-Awake
    }
}
