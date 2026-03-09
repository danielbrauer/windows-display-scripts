# Register scheduled tasks for TV and Steam control.
# Must be run as Administrator.

#Requires -RunAsAdministrator

# --- Turn on TV on wake ---

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
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -ExecutionPolicy Bypass -File "$WakeScriptPath"</Arguments>
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
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -ExecutionPolicy Bypass -File "$SleepScriptPath"</Arguments>
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
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -ExecutionPolicy Bypass -File "$ControllerScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName $ControllerTaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $ControllerTaskName -Xml $controllerXml
Write-Output "Scheduled task '$ControllerTaskName' registered. It runs at logon and reacts to controller connections."

# --- Keep machine awake while SSH sessions are active ---

$SSHAwakeScriptPath = Join-Path $PSScriptRoot "Monitor-SSHAwake.ps1"
$SSHAwakeTaskName = "MonitorSSHAwake"

# Runs at logon as a background process that watches for sshd process events
$sshAwakeXml = @"
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
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -ExecutionPolicy Bypass -File "$SSHAwakeScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName $SSHAwakeTaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $SSHAwakeTaskName -Xml $sshAwakeXml
Write-Output "Scheduled task '$SSHAwakeTaskName' registered. It runs at logon and watches for SSH sessions."

# --- Enable Parsec + VDD on demand ---

$ParsecEnableScriptPath = Join-Path $PSScriptRoot "parsec-enable.ps1"
$ParsecEnableTaskName = "ParsecEnable"

# On-demand task (no trigger). Enables the VDD and Parsec service, then monitors
# for disconnects and auto-shuts down after 5 minutes of inactivity.
# Requires HighestAvailable to call Enable-PnpDevice / Disable-PnpDevice.
$parsecEnableXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers/>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
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
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -ExecutionPolicy Bypass -File "$ParsecEnableScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName $ParsecEnableTaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $ParsecEnableTaskName -Xml $parsecEnableXml
Write-Output "Scheduled task '$ParsecEnableTaskName' registered. Run parsec-on.sh to enable Parsec."

# --- Disable Parsec + VDD on demand ---

$ParsecDisableScriptPath = Join-Path $PSScriptRoot "parsec-disable.ps1"
$ParsecDisableTaskName = "ParsecDisable"

# On-demand task (no trigger). Stops the ParsecEnable monitor, Parsec service, and VDD.
$parsecDisableXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers/>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
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
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -ExecutionPolicy Bypass -File "$ParsecDisableScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Unregister-ScheduledTask -TaskName $ParsecDisableTaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $ParsecDisableTaskName -Xml $parsecDisableXml
Write-Output "Scheduled task '$ParsecDisableTaskName' registered. Run parsec-off.sh to disable Parsec."
