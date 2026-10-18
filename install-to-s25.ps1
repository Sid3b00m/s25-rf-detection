<#
  Installs RF Sentinel + OVERWATCH on a USB-connected Galaxy S25 and applies
  the runtime permissions and battery settings both apps need to keep scanning.

  Prerequisites on the phone:
    1. Settings > Security and privacy > Auto Blocker  -> OFF
    2. Settings > About phone > Software information > tap "Build number" 7x
    3. Settings > Developer options > USB debugging    -> ON
    4. Plug into USB and accept the "Allow USB debugging?" prompt

  Run:  powershell -ExecutionPolicy Bypass -File .\install-to-s25.ps1
#>

$ErrorActionPreference = 'Stop'

$adb     = Join-Path $env:LOCALAPPDATA 'Android\platform-tools\adb.exe'
$apkDir  = 'C:\Users\ub3r\rf-apks'

$apps = @(
    @{ Name = 'RF Sentinel'; Pkg = 'com.rfsentinel.app';      Apk = 'RFSentinel-v2.24.0-release.apk' }
    @{ Name = 'OVERWATCH';   Pkg = 'org.soulstone.overwatch'; Apk = 'OVERWATCH-v0.5.19.apk' }
)

# Runtime permissions both apps declare. Neither declares ACCESS_BACKGROUND_LOCATION:
# they rely on a FOREGROUND_SERVICE_LOCATION service to keep scanning screen-off.
$runtimePerms = @(
    'android.permission.ACCESS_FINE_LOCATION'
    'android.permission.ACCESS_COARSE_LOCATION'
    'android.permission.BLUETOOTH_SCAN'
    'android.permission.BLUETOOTH_CONNECT'
    'android.permission.NEARBY_WIFI_DEVICES'
    'android.permission.POST_NOTIFICATIONS'
)

function Invoke-Adb { & $adb @args 2>&1 }

if (-not (Test-Path $adb)) { throw "adb not found at $adb" }

Write-Host 'Waiting for a device over USB (Ctrl+C to abort)...' -ForegroundColor Cyan
Invoke-Adb wait-for-device | Out-Null

$model  = (Invoke-Adb shell getprop ro.product.model).Trim()
$rel    = (Invoke-Adb shell getprop ro.build.version.release).Trim()
$sdk    = (Invoke-Adb shell getprop ro.build.version.sdk).Trim()
$abi    = (Invoke-Adb shell getprop ro.product.cpu.abi).Trim()
Write-Host "Connected: $model | Android $rel (API $sdk) | $abi" -ForegroundColor Green

foreach ($app in $apps) {
    $apkPath = Join-Path $apkDir $app.Apk
    if (-not (Test-Path $apkPath)) { throw "Missing APK: $apkPath" }

    Write-Host ''
    Write-Host "=== $($app.Name) ($($app.Pkg)) ===" -ForegroundColor Yellow

    Write-Host '  installing...'
    $out = Invoke-Adb install -r -g $apkPath
    if ($out -match 'Success') {
        Write-Host '  installed' -ForegroundColor Green
    } else {
        # -g (grant all) can fail on some One UI builds; retry without it.
        Write-Host '  retrying without auto-grant...' -ForegroundColor DarkYellow
        $out = Invoke-Adb install -r $apkPath
        if ($out -match 'Success') { Write-Host '  installed' -ForegroundColor Green }
        else { Write-Host "  INSTALL FAILED: $out" -ForegroundColor Red; continue }
    }

    Write-Host '  granting runtime permissions...'
    foreach ($p in $runtimePerms) {
        $r = Invoke-Adb shell pm grant $app.Pkg $p
        $short = $p -replace '^android\.permission\.', ''
        if ("$r".Trim()) { Write-Host "    $short : skipped ($("$r".Trim()))" -ForegroundColor DarkGray }
        else             { Write-Host "    $short : granted" -ForegroundColor Green }
    }

    Write-Host '  exempting from battery optimisation / app sleep...'
    Invoke-Adb shell dumpsys deviceidle whitelist +$($app.Pkg) | Out-Null
    Invoke-Adb shell am set-standby-bucket $app.Pkg active      | Out-Null
    Invoke-Adb shell cmd appops set $app.Pkg RUN_ANY_IN_BACKGROUND allow | Out-Null
    Write-Host '    doze whitelist + standby bucket active' -ForegroundColor Green
}

# RF Sentinel's floating threat bubble and mini map need overlay permission.
Write-Host ''
Write-Host 'Enabling floating-window overlay for RF Sentinel...' -ForegroundColor Yellow
Invoke-Adb shell appops set com.rfsentinel.app SYSTEM_ALERT_WINDOW allow | Out-Null
Write-Host '  SYSTEM_ALERT_WINDOW allowed' -ForegroundColor Green

Write-Host ''
Write-Host '--- verification ---' -ForegroundColor Cyan
foreach ($app in $apps) {
    $v = (Invoke-Adb shell dumpsys package $app.Pkg | Select-String 'versionName=') | Select-Object -First 1
    Write-Host ("{0,-12} {1}" -f $app.Name, "$v".Trim())
}
Write-Host ''
Write-Host 'Done. Open RF Sentinel and run its setup wizard.' -ForegroundColor Green
