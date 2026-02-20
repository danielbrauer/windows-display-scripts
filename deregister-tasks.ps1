# Deregister all scheduled tasks created by register-task.ps1.
# Must be run as Administrator.

#Requires -RunAsAdministrator

$TaskNames = @("TurnOnTvOnWake", "TurnOffTvOnSleep", "OnControllerConnect")

foreach ($name in $TaskNames) {
    if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Output "Removed scheduled task '$name'."
    } else {
        Write-Output "Scheduled task '$name' not found, skipping."
    }
}
