<#
.SYNOPSIS
    Converts an RF Sentinel CSV export into WiGLE's WigleWifi-1.4 upload format.

.DESCRIPTION
    RF Sentinel has no native WiGLE export. Three of its CSV exports carry coordinates and
    can be converted; the fourth cannot. This script auto-detects which one you gave it.

        Export scope                            Convertible
        --------------------------------------  -----------------------------------------
        All nearby devices - this scan          yes
        Match log only                          yes
        Trip devices                            yes
        All devices ever seen - history         NO - the history CSV has no lat/lon at all

    Columns WiGLE wants that RF Sentinel never records are emitted empty rather than guessed:
    AuthMode, Channel, AltitudeMeters and (unless you pass -AssumeAccuracyMeters) AccuracyMeters.
    In particular the `distance_m` column is an estimated distance to the *device* and is not
    GPS accuracy, so it is deliberately not mapped.

.PARAMETER Radio
    Limit output to one radio. BLE and WiFi rows are both valid WiGLE submissions.

.PARAMETER KeepRandomAddresses
    By default, BLE devices whose address_type is not public are dropped. Those MACs are
    rotated by the device and are meaningless as persistent WiGLE observations.

.PARAMETER AssumeAccuracyMeters
    Writes a fixed AccuracyMeters for every row. Only use this if you know roughly what your
    GPS accuracy was; an invented number is worse than an empty one.

.EXAMPLE
    .\csv-to-wigle.ps1 .\rfsentinel_session.csv

.EXAMPLE
    .\csv-to-wigle.ps1 .\rfsentinel_session.csv -Radio WiFi -OutFile wigle_upload.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string] $Path,

    [string] $OutFile,

    [ValidateSet('All', 'WiFi', 'Bluetooth')]
    [string] $Radio = 'All',

    [switch] $KeepRandomAddresses,

    [double] $AssumeAccuracyMeters = -1,

    [string] $Model   = 'SM-S931U',
    [string] $Brand   = 'samsung',
    [string] $Device  = 'Galaxy S25',
    [string] $Release = '16'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path)) { throw "No such file: $Path" }
if (-not $OutFile) {
    $OutFile = Join-Path (Split-Path -Parent (Resolve-Path $Path)) `
        ("{0}_wigle.csv" -f [IO.Path]::GetFileNameWithoutExtension($Path))
}

$rows = @(Import-Csv -LiteralPath $Path)
if ($rows.Count -eq 0) { throw "The CSV is empty." }

$cols = $rows[0].PSObject.Properties.Name

# --- identify which RF Sentinel export this is -------------------------------------------
if ($cols -contains 'address_type' -and $cols -contains 'radios') {
    $shape = 'session'
} elseif ($cols -contains 'timestamp' -and $cols -contains 'device_name') {
    $shape = 'matchlog'
} elseif ($cols -contains 'label' -and $cols -contains 'requested_networks') {
    $shape = 'trip'
} elseif ($cols -contains 'detect_count') {
    Write-Host ""
    Write-Host "This is the 'All devices ever seen - history' export, which records no" -ForegroundColor Yellow
    Write-Host "coordinates. WiGLE submissions must be geolocated, so there is nothing" -ForegroundColor Yellow
    Write-Host "here to convert." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Re-export from RF Sentinel using 'All nearby devices - this scan' or"
    Write-Host "'Match log only' instead - both carry latitude and longitude."
    Write-Host ""
    exit 2
} else {
    throw "Unrecognised CSV. Columns found: $($cols -join ', ')"
}

if ($cols -notcontains 'latitude' -or $cols -notcontains 'longitude') {
    throw "Detected the '$shape' export but it has no latitude/longitude columns."
}

Write-Host "Input    : $Path"
Write-Host "Detected : $shape export, $($rows.Count) rows"

# --- field accessors per shape -----------------------------------------------------------
$ssidCol  = if ($shape -eq 'matchlog') { 'device_name' } else { 'name' }
$timeCol  = if ($shape -eq 'matchlog') { 'timestamp' }   else { 'first_seen' }
$radioCol = if ($shape -eq 'session')  { 'radios' }      else { 'source' }

function Get-RadioTypes([string] $raw) {
    # WigleWifi Type column: W = WiFi, E = BLE, B = Bluetooth classic.
    # A device heard on two radios is two genuine observations, so emit one row for each.
    $v = ($raw | ForEach-Object { $_ }) -as [string]
    if (-not $v) { return @() }
    $v = $v.ToLowerInvariant()
    $t = @()
    if ($v -match 'wifi|wlan|802') { $t += 'W' }
    if ($v -match 'ble|low.?energy') { $t += 'E' }
    elseif ($v -match 'bt|bluetooth|classic') { $t += 'B' }
    return $t
}

$skip = [ordered]@{
    'no coordinates'       = 0
    'randomized BLE MAC'   = 0
    'unknown radio'        = 0
    'filtered by -Radio'   = 0
    'malformed MAC'        = 0
}

$out = New-Object System.Collections.Generic.List[string]

foreach ($r in $rows) {

    $lat = $r.latitude
    $lon = $r.longitude
    if ([string]::IsNullOrWhiteSpace($lat) -or [string]::IsNullOrWhiteSpace($lon)) {
        $skip['no coordinates']++ ; continue
    }

    $mac = ($r.mac -replace '[^0-9A-Fa-f:]', '').ToUpperInvariant()
    if ($mac -notmatch '^([0-9A-F]{2}:){5}[0-9A-F]{2}$') { $skip['malformed MAC']++ ; continue }

    $types = Get-RadioTypes $r.$radioCol
    if ($types.Count -eq 0) { $skip['unknown radio']++ ; continue }

    # Rotated BLE addresses are not stable identifiers and pollute the database.
    if (-not $KeepRandomAddresses -and $shape -eq 'session') {
        if ($r.address_type -and $r.address_type -notmatch '(?i)public') {
            $skip['randomized BLE MAC']++ ; continue
        }
    }

    $rssi = if (-not [string]::IsNullOrWhiteSpace($r.rssi)) { $r.rssi }
            elseif ($cols -contains 'best_rssi')            { $r.best_rssi }
            else                                            { '' }

    $acc = if ($AssumeAccuracyMeters -ge 0) { $AssumeAccuracyMeters } else { '' }

    foreach ($t in $types) {
        if ($Radio -eq 'WiFi'      -and $t -ne 'W') { $skip['filtered by -Radio']++ ; continue }
        if ($Radio -eq 'Bluetooth' -and $t -eq 'W') { $skip['filtered by -Radio']++ ; continue }

        $ssid = ($r.$ssidCol -replace '"', '""')
        if ($ssid -match '[,"]') { $ssid = '"' + $ssid + '"' }

        # MAC,SSID,AuthMode,FirstSeen,Channel,RSSI,Lat,Lon,Altitude,Accuracy,Type
        $out.Add(('{0},{1},,{2},,{3},{4},{5},,{6},{7}' -f `
            $mac, $ssid, $r.$timeCol, $rssi, $lat, $lon, $acc, $t))
    }
}

if ($out.Count -eq 0) {
    Write-Warning "Nothing to write - every row was skipped."
    $skip.GetEnumerator() | Where-Object { $_.Value -gt 0 } |
        ForEach-Object { Write-Host ("  skipped, {0}: {1}" -f $_.Key, $_.Value) }
    return
}

$preamble = "WigleWifi-1.4,appRelease=rfsentinel-export,model=$Model,release=$Release," +
            "device=$Device,display=,board=,brand=$Brand"
$header   = 'MAC,SSID,AuthMode,FirstSeen,Channel,RSSI,CurrentLatitude,CurrentLongitude,' +
            'AltitudeMeters,AccuracyMeters,Type'

Set-Content -LiteralPath $OutFile -Encoding ascii -Value (@($preamble, $header) + $out)

Write-Host "Output   : $OutFile"
Write-Host "Written  : $($out.Count) observations"
$skip.GetEnumerator() | Where-Object { $_.Value -gt 0 } |
    ForEach-Object { Write-Host ("  skipped, {0}: {1}" -f $_.Key, $_.Value) }

Write-Host ""
Write-Host "AuthMode, Channel and AltitudeMeters are empty because RF Sentinel does not record"
Write-Host "them. WiGLE accepts the rows but ranks sparse observations lower."
