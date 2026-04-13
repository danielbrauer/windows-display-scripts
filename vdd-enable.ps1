# vdd-enable.ps1 — Configure the community Virtual Display Driver (MttVDD/HDR fork)
# to expose one virtual monitor with 3840x2160 @ 120Hz available, then restart the
# adapter so the change takes effect. Requires admin.

$ErrorActionPreference = 'Stop'

$SettingsPath = 'C:\VirtualDisplayDriver\vdd_settings.xml'
$DeviceId     = 'ROOT\DISPLAY\0000'
$TargetWidth  = 3840
$TargetHeight = 2160
$TargetHz     = 120

# Self-elevate
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

if (-not (Test-Path $SettingsPath)) {
    throw "vdd_settings.xml not found at $SettingsPath"
}

[xml]$xml = Get-Content $SettingsPath

# 1 monitor
$xml.vdd_settings.monitors.count = '1'

# Ensure target refresh rate is present globally (replicated to every resolution)
$global = $xml.vdd_settings.global
$hasHz  = @($global.g_refresh_rate) -contains "$TargetHz"
if (-not $hasHz) {
    $node = $xml.CreateElement('g_refresh_rate')
    $node.InnerText = "$TargetHz"
    [void]$global.AppendChild($node)
}

# Ensure 3840x2160 resolution is present
$resolutions = $xml.vdd_settings.resolutions
$has4k = $false
foreach ($r in $resolutions.resolution) {
    if ([int]$r.width -eq $TargetWidth -and [int]$r.height -eq $TargetHeight) { $has4k = $true; break }
}
if (-not $has4k) {
    $r = $xml.CreateElement('resolution')
    foreach ($pair in @(@('width',$TargetWidth), @('height',$TargetHeight), @('refresh_rate',$TargetHz))) {
        $el = $xml.CreateElement($pair[0]); $el.InnerText = "$($pair[1])"; [void]$r.AppendChild($el)
    }
    [void]$resolutions.AppendChild($r)
}

$xml.Save($SettingsPath)
Write-Host "Updated $SettingsPath (count=1, ${TargetWidth}x${TargetHeight}@${TargetHz}Hz available)"

Write-Host "Restarting $DeviceId ..."
& pnputil /restart-device "$DeviceId"
Write-Host "Done. Set the display mode to ${TargetWidth}x${TargetHeight}@${TargetHz} in Windows Display Settings."
