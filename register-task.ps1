# Register scheduled tasks for TV and Steam control.
# Must be run as Administrator.

#Requires -RunAsAdministrator

# --- Turn on TV on wake ---

$LauncherPath = Join-Path $PSScriptRoot "launch-hidden.vbs"
$WakeScriptPath = Join-Path $PSScriptRoot "on-wake.ps1"
$WakeTaskName = "TurnOnTvOnWake"

# Build the task using XML to get the proper EventTrigger (not exposed by New-ScheduledTaskTrigger)
# Triggers on Event ID 1 from Power-Troubleshooter, which fires when the system resumes from sleep
$wakeXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"$LauncherPath" "$WakeScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName $WakeTaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $WakeTaskName -Xml $wakeXml
Write-Output "Scheduled task '$WakeTaskName' registered. It will run on-wake.ps1 on wake from sleep."

# --- Turn off TV before sleep (background listener) ---

$SleepScriptPath = Join-Path $PSScriptRoot "on-sleep.ps1"
$SleepTaskName = "TurnOffTvOnSleep"

# Runs at logon as a background process that listens for the pre-sleep PowerModeChanged event
$sleepXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"$LauncherPath" "$SleepScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName $SleepTaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $SleepTaskName -Xml $sleepXml
Write-Output "Scheduled task '$SleepTaskName' registered. It runs at logon and listens for sleep events."

# --- React to controller connection (background listener) ---

$ControllerScriptPath = Join-Path $PSScriptRoot "on-controller-connect.ps1"
$ControllerTaskName = "OnControllerConnect"

# Runs at logon as a background process that listens for device-arrival WMI events
$controllerXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"$LauncherPath" "$ControllerScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName $ControllerTaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $ControllerTaskName -Xml $controllerXml
Write-Output "Scheduled task '$ControllerTaskName' registered. It runs at logon and reacts to controller connections."
