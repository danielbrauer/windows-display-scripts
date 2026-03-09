# Enables the virtual display and Parsec service, then monitors for disconnects.
# Automatically disables both 5 minutes after a Parsec client disconnects.
# Triggered on-demand via the ParsecEnable scheduled task.

. "$PSScriptRoot\config.ps1"
$LogFile = Join-Path $PSScriptRoot "parsec.log"
function Write-Log($msg) {
    if (-not $LogToFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts  $msg" | Out-File -Append -FilePath $LogFile
}

$DeviceId = 'ROOT\DISPLAY\0000'
$ParsecLogPath = Join-Path $env:APPDATA "Parsec\log.txt"
$ConnectPattern = ' connected\.$'
$DisconnectPattern = ' disconnected\.$'
$ShutdownDelay = 300  # seconds

Write-Log "=== parsec-enable.ps1 started ==="

Enable-PnpDevice -InstanceId $DeviceId -Confirm:$false -ErrorAction SilentlyContinue
Write-Log "VDD enabled"

Start-Service Parsec -ErrorAction SilentlyContinue
Write-Log "Parsec service started"

# Open a StreamReader at the end of the file
function Open-LogReader {
    if (-not (Test-Path $ParsecLogPath)) { return $null }
    $fileInfo = [System.IO.FileInfo]::new($ParsecLogPath)
    $stream = [System.IO.FileStream]::new(
        $ParsecLogPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
    )
    $stream.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
    $reader = [System.IO.StreamReader]::new($stream)
    return @{
        Reader       = $reader
        CreationTime = $fileInfo.CreationTime
    }
}

function Test-LogRotated($readerInfo) {
    if (-not (Test-Path $ParsecLogPath)) { return $true }
    $fileInfo = [System.IO.FileInfo]::new($ParsecLogPath)
    if ($fileInfo.CreationTime -ne $readerInfo.CreationTime) { return $true }
    if ($fileInfo.Length -lt $readerInfo.Reader.BaseStream.Position) { return $true }
    return $false
}

$readerInfo = Open-LogReader
$disableAt = $null

try {
    while ($true) {
        Start-Sleep -Seconds 1

        if (-not (Test-Path $ParsecLogPath)) {
            if ($readerInfo) {
                $readerInfo.Reader.Dispose()
                $readerInfo = $null
                Write-Log "Log file disappeared"
            }
        }
        elseif (-not $readerInfo -or (Test-LogRotated $readerInfo)) {
            if ($readerInfo) {
                $readerInfo.Reader.Dispose()
                Write-Log "Log rotation detected"
            }
            $fileInfo = [System.IO.FileInfo]::new($ParsecLogPath)
            $stream = [System.IO.FileStream]::new(
                $ParsecLogPath,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            )
            $reader = [System.IO.StreamReader]::new($stream)
            $readerInfo = @{
                Reader       = $reader
                CreationTime = $fileInfo.CreationTime
            }
        }

        if ($readerInfo) {
            while ($null -ne ($line = $readerInfo.Reader.ReadLine())) {
                if ($line -match $ConnectPattern) {
                    Write-Log "Connect: $line"
                    $disableAt = $null
                }
                elseif ($line -match $DisconnectPattern) {
                    Write-Log "Disconnect: $line"
                    $disableAt = (Get-Date).AddSeconds($ShutdownDelay)
                    Write-Log "Shutdown at $($disableAt.ToString('HH:mm:ss'))"
                }
            }
        }

        if ($disableAt -and (Get-Date) -ge $disableAt) {
            Write-Log "Shutdown timer expired"
            break
        }
    }

    # Timer expired — clean up
    Disable-PnpDevice -InstanceId $DeviceId -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "VDD disabled"
    Stop-Service Parsec -Force -ErrorAction SilentlyContinue
    Write-Log "Parsec stopped"
    Write-Log "Parsec stopped, exiting"
} finally {
    if ($readerInfo) { $readerInfo.Reader.Dispose() }
}
