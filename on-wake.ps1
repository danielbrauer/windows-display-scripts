# Turn on the TV and launch Steam Big Picture if an Xbox controller is connected.
# Intended to run on wake from sleep via Task Scheduler.

. "$PSScriptRoot\config.ps1"
$TvApiUrl = "$TvApiOrigin/tv/on"

# Use XInput to check for a connected controller
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

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
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

if (-not (Test-XboxControllerConnected)) {
    Write-Output "No Xbox controller connected. Skipping."
    exit
}

$mutexName = "Global\DisplayScriptsMutex"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
if (-not $mutex.WaitOne(0)) {
    Write-Output "Another display script is running. Skipping."
    $mutex.Dispose()
    exit
}

$startTime = Get-Date
try {
    if (-not (Get-Process -Name "steam" -ErrorAction SilentlyContinue)) {
        Start-Process "steam://open/bigpicture"
        Write-Output "Steam launched in Big Picture mode."
    } else {
        Start-Process "steam://open/bigpicture"
        $steamProc = Get-Process -Name "steam" -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
            Select-Object -First 1
        if ($steamProc) {
            [XInput]::ShowWindow($steamProc.MainWindowHandle, 9)  # SW_RESTORE
        }
        Write-Output "Steam brought to foreground in Big Picture mode."
    }

    try {
        $body = @{ input = "1" } | ConvertTo-Json
        Invoke-RestMethod -Uri $TvApiUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
        Write-Output "TV turned on."
    } catch {
        Write-Error "Failed to reach TV API: $_"
    }

    $elapsed = (Get-Date) - $startTime
    $remaining = 15 - $elapsed.TotalSeconds
    if ($remaining -gt 0) {
        Start-Sleep -Seconds $remaining
    }
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
