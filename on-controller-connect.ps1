# Background process that listens for Xbox controller connections via the
# Xbox Wireless Adapter.  When a controller connects, turns on the TV
# (switching to HDMI 1) and launches Steam Big Picture.

. "$PSScriptRoot\config.ps1"
$TvApiUrl = "$TvApiOrigin/tv/on"

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
    public static extern bool SetForegroundWindow(IntPtr hWnd);

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

# Track initial state so we only fire on transitions
$wasConnected = Test-XboxControllerConnected

Register-WmiEvent -Class Win32_DeviceChangeEvent -SourceIdentifier "ControllerWatch" | Out-Null

while ($true) {
    $ev = Wait-Event -SourceIdentifier "ControllerWatch"
    Remove-Event -EventIdentifier $ev.EventIdentifier

    # Brief pause so XInput state reflects the change
    Start-Sleep -Milliseconds 500

    $isConnected = Test-XboxControllerConnected

    if ($isConnected -and -not $wasConnected) {
        $mutexName = "Global\DisplayScriptsMutex"
        $mutex = New-Object System.Threading.Mutex($false, $mutexName)
        if (-not $mutex.WaitOne(0)) {
            Write-Output "Another display script is running. Skipping."
            $mutex.Dispose()
        } else {
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
                        [XInput]::SetForegroundWindow($steamProc.MainWindowHandle)
                    }
                    Write-Output "Steam brought to foreground in Big Picture mode."
                }

                try {
                    $body = @{ input = "1" } | ConvertTo-Json
                    Invoke-RestMethod -Uri $TvApiUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
                    Write-Output "TV turned on (HDMI 1)."
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
        }

        # Drain stale events that queued up during the hold and re-read state
        while ($stale = Get-Event -SourceIdentifier "ControllerWatch" -ErrorAction SilentlyContinue) {
            Remove-Event -EventIdentifier $stale.EventIdentifier
        }
        $isConnected = Test-XboxControllerConnected
    }

    $wasConnected = $isConnected
}
