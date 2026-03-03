# Restart the background listener tasks to pick up script changes.
# Must be run as Administrator.

#Requires -RunAsAdministrator

$TaskNames = @("TurnOffTvOnSleep", "OnControllerConnect", "MonitorSSHAwake")

foreach ($name in $TaskNames) {
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Output "Scheduled task '$name' not found, skipping."
        continue
    }
    Stop-ScheduledTask -TaskName $name
    Start-ScheduledTask -TaskName $name
    Write-Output "Restarted '$name'."
}
