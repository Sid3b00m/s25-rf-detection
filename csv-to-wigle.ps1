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
    By default, randomized addresses are dropped. Those MACs are rotated by the device and are
    meaningless as persistent WiGLE observations. The session export reports an address_type
    and that is used directly; the match log and trip exports do not, so the address is
    classified from its own bits instead - see -OuiFile.

.PARAMETER OuiFile
    Optional path to a Wireshark-style `manuf` file. Without it, randomized addresses are
    detected by the locally-administered bit alone, which is decisive but incomplete for BLE:
    a BLE random address is only required to set the top two bits, so one that leaves the
    locally-administered bit clear can only be identified by its OUI being absent from the
    IEEE registry. Supply the registry to catch those too.

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

    [string] $OuiFile,

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

# --- IEEE registry, optional -------------------------------------------------------------
$registry = $null
if (-not $OuiFile) {
    $local = Join-Path (Split-Path -Parent $PSCommandPath) 'ieee\manuf'
    if (Test-Path -LiteralPath $local) { $OuiFile = $local }
}
if ($OuiFile) {
    if (-not (Test-Path -LiteralPath $OuiFile)) { throw "No such OUI file: $OuiFile" }
    $registry = @{}
    foreach ($line in [IO.File]::ReadLines((Resolve-Path $OuiFile))) {
        if ($line.StartsWith('#') -or -not $line.Trim()) { continue }
        $p = $line -split "`t"
        if ($p.Count -lt 2) { continue }
        $a = $p[0].Trim(); $bits = 24
        if ($a -match '^(.*)/(\d+)$') { $a = $Matches[1]; $bits = [int]$Matches[2] }
        $h = ($a -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
        $keep = [int][Math]::Ceiling($bits / 4)
        if ($h.Length -lt $keep) { continue }
        $k = $h.Substring(0, $keep)
        if (-not $registry.ContainsKey($k)) { $registry[$k] = $true }
    }
    Write-Host "Registry : $OuiFile ($($registry.Count) assignments)"
} else {
    Write-Host "Registry : none - BLE random addresses that leave the locally-administered" -ForegroundColor DarkYellow
    Write-Host "           bit clear cannot be told from public ones and will be kept." -ForegroundColor DarkYellow
    Write-Host "           Fetch one with:" -ForegroundColor DarkYellow
    Write-Host "             iwr https://www.wireshark.org/download/automated/data/manuf -OutFile ieee\manuf"
}

function Test-Registered([string] $hex) {
    if (-not $registry) { return $false }
    for ($len = 12; $len -ge 6; $len--) {
        if ($hex.Length -lt $len) { continue }
        if ($registry.ContainsKey($hex.Substring(0, $len))) { return $true }
    }
    return $false
}

function Get-MacClass {
    param([string] $Hex, [string] $Type)

    $b0 = [Convert]::ToInt32($Hex.Substring(0, 2), 16)

    # No IEEE assignment ever sets the locally-administered bit, so this alone is proof the
    # address was generated rather than issued. Holds for WiFi and Bluetooth alike.
    if ($b0 -band 0x02) { return 'random' }

    if ($Type -eq 'W') { return 'public' }

    # A BLE random address only has to set the top two bits; the locally-administered bit is
    # unconstrained. So an unregistered OUI is what separates the remaining random addresses
    # from genuine public ones, and without the registry they are indistinguishable.
    if ($registry -and -not (Test-Registered $Hex)) {
        switch ($b0 -shr 6) {
            3 { return 'random' }   # 11 static
            1 { return 'random' }   # 01 resolvable private
            0 { return 'random' }   # 00 non-resolvable private
            2 { return 'reserved' } # 10 invalid per spec
        }
    }
    return 'public'
}

$skip = [ordered]@{
    'no coordinates'           = 0
    'randomized, reported'     = 0
    'randomized, from bits'    = 0
    'reserved address bits'    = 0
    'unknown radio'            = 0
    'filtered by -Radio'       = 0
    'malformed MAC'            = 0
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

    # Rotated addresses are not stable identifiers and pollute a database keyed on MAC.
    # Prefer what the app reported; fall back to classifying the address itself.
    $reported = $null
    if ($cols -contains 'address_type' -and -not [string]::IsNullOrWhiteSpace($r.address_type)) {
        $reported = $r.address_type
    }
    if (-not $KeepRandomAddresses -and $reported -and $reported -notmatch '(?i)public') {
        $skip['randomized, reported']++ ; continue
    }

    $hex = $mac -replace ':', ''

    $rssi = if (-not [string]::IsNullOrWhiteSpace($r.rssi)) { $r.rssi }
            elseif ($cols -contains 'best_rssi')            { $r.best_rssi }
            else                                            { '' }

    $acc = if ($AssumeAccuracyMeters -ge 0) { $AssumeAccuracyMeters } else { '' }

    foreach ($t in $types) {
        if ($Radio -eq 'WiFi'      -and $t -ne 'W') { $skip['filtered by -Radio']++ ; continue }
        if ($Radio -eq 'Bluetooth' -and $t -eq 'W') { $skip['filtered by -Radio']++ ; continue }

        if (-not $KeepRandomAddresses -and -not $reported) {
            $cls = Get-MacClass -Hex $hex -Type $t
            if ($cls -eq 'random')   { $skip['randomized, from bits']++ ; continue }
            if ($cls -eq 'reserved') { $skip['reserved address bits']++ ; continue }
        }

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
