# Turn on the TV unless the machine was recently woken over LAN.
# Intended to run on wake from sleep via Task Scheduler.

. "$PSScriptRoot\config.ps1"
$TvApiUrl = "$TvApiOrigin/tv/on"
$WolApiUrl = "$WolApiOrigin/wol/last-wake/$WolTargetName"

$LogFile = Join-Path $PSScriptRoot "on-wake.log"
function Write-Log($msg) {
    if (-not $LogToFile) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "$ts  $msg" | Out-File -Append -FilePath $LogFile
}
Write-Log "=== on-wake.ps1 started ==="

# Check if this wake was triggered by Wake-on-LAN
try {
    Write-Log "Querying WoL endpoint: $WolApiUrl"
    $lastWake = Invoke-RestMethod -Uri $WolApiUrl -Method Get -TimeoutSec 10
    if ($lastWake.last_wake) {
        $lastWakeTime = [DateTimeOffset]::Parse($lastWake.last_wake).LocalDateTime
        $elapsed = (Get-Date) - $lastWakeTime
        if ($elapsed.TotalSeconds -lt 30) {
            Write-Log "WoL wake was $([math]::Round($elapsed.TotalSeconds, 1))s ago. Skipping TV."
            exit
        }
        Write-Log "WoL wake was $([math]::Round($elapsed.TotalSeconds, 1))s ago. Proceeding."
    } else {
        Write-Log "No WoL record found. Proceeding."
    }
} catch {
    Write-Log "ERROR querying WoL endpoint: $_"
    Write-Log "Proceeding with TV on."
}

try {
    Write-Log "Sending POST to $TvApiUrl ..."
    $body = @{ source = $TvSourceName } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri $TvApiUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 15
    Write-Log "TV API responded: $response"
} catch {
    Write-Log "ERROR calling TV API: $_"
}

$AmpApiUrl = "$TvApiOrigin/amp/on"
try {
    Write-Log "Sending POST to $AmpApiUrl ..."
    $response = Invoke-RestMethod -Uri $AmpApiUrl -Method Post -TimeoutSec 15
    Write-Log "Amp API responded: $response"
} catch {
    Write-Log "ERROR calling Amp API: $_"
}
