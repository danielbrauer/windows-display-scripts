# Background process that listens for Xbox controller connections via the
# Xbox Wireless Adapter. When a controller connects, launches Steam if not running.

. "$PSScriptRoot\config.ps1"
$LogFile = Join-Path $PSScriptRoot "on-controller-connect.log"
function Write-Log($msg) {
    if (-not $LogToFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts  $msg" | Out-File -Append -FilePath $LogFile
}
Write-Log "=== on-controller-connect.ps1 started ==="

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class XInput {
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_STATE {
        public uint dwPacketNumber;
        public XINPUT_GAMEPAD Gamepad;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_GAMEPAD {
        public ushort wButtons;
        public byte bLeftTrigger;
        public byte bRightTrigger;
        public short sThumbLX;
        public short sThumbLY;
        public short sThumbRX;
        public short sThumbRY;
    }

    [DllImport("xinput1_4.dll")]
    public static extern uint XInputGetState(uint dwUserIndex, ref XINPUT_STATE pState);
}
"@

function Test-XboxControllerConnected {
    $state = New-Object XInput+XINPUT_STATE
    for ($i = 0; $i -lt 4; $i++) {
        $result = [XInput]::XInputGetState($i, [ref]$state)
        if ($result -eq 0) {
            return $true
        }
    }
    return $false
}

# Track initial state so we only fire on transitions
$wasConnected = Test-XboxControllerConnected
Write-Log "Initial controller state: connected=$wasConnected"

Register-WmiEvent -Class Win32_DeviceChangeEvent -SourceIdentifier "ControllerWatch" | Out-Null

while ($true) {
    $ev = Wait-Event -SourceIdentifier "ControllerWatch"
    Remove-Event -EventIdentifier $ev.EventIdentifier

    # Brief pause so XInput state reflects the change
    Start-Sleep -Milliseconds 500

    $isConnected = Test-XboxControllerConnected
    Write-Log "DeviceChangeEvent: isConnected=$isConnected wasConnected=$wasConnected"

    if ($isConnected -and -not $wasConnected) {
        Write-Log "Controller connected."
        if (-not (Get-Process -Name "steam" -ErrorAction SilentlyContinue)) {
            Start-Process "steam://open/bigpicture"
            Write-Log "Steam launched in Big Picture mode."
        } else {
            Write-Log "Steam already running."
        }
    }

    $wasConnected = $isConnected
}
