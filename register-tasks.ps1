# Register scheduled tasks for controller, SSH awake, and Parsec control.
# Must be run as Administrator.

#Requires -RunAsAdministrator

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
