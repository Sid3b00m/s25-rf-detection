<#
  Audits every MAC prefix in RF Sentinel's watchlist presets against the IEEE
  registry, using Wireshark's IEEE-derived 'manuf' file as ground truth.

  standards-oui.ieee.org answers scripted requests with HTTP 418, so manuf is
  the practical source. It carries MA-L (/24), MA-M (/28) and MA-S (/36).

  Reports, for each prefix: the registrant IEEE actually lists, and whether it
  corroborates the vendor named in the preset's own label.
#>

param(
    [string]$ManufPath = "$PSScriptRoot\ieee\manuf",
    [string[]]$Presets = @('global', 'us', 'canada', 'uk', 'france', 'germany', 'spain', 'italy', 'portugal')
)

$ErrorActionPreference = 'Stop'

# ---- load the registry -------------------------------------------------
$reg = @{}
foreach ($line in [System.IO.File]::ReadLines($ManufPath)) {
    if ($line.StartsWith('#') -or $line.Trim() -eq '') { continue }
    $parts = $line -split "`t"
    if ($parts.Count -lt 2) { continue }

    $addr = $parts[0].Trim()
    $bits = 24
    if ($addr -match '^(.*)/(\d+)$') { $addr = $Matches[1]; $bits = [int]$Matches[2] }

    $hex = ($addr -replace '[^0-9A-Fa-f]', '').ToUpper()
    $keep = [int][Math]::Ceiling($bits / 4)
    if ($hex.Length -lt $keep) { continue }
    $key = $hex.Substring(0, $keep)

    # long name if present, else the short name
    $name = if ($parts.Count -ge 3 -and $parts[2].Trim()) { $parts[2].Trim() } else { $parts[1].Trim() }
    if (-not $reg.ContainsKey($key)) { $reg[$key] = $name }
}
Write-Host "Registry: $($reg.Count) assignments loaded from manuf" -ForegroundColor Cyan

# ---- longest-prefix lookup --------------------------------------------
function Resolve-Oui([string]$prefix) {
    $hex = ($prefix -replace '[^0-9A-Fa-f]', '').ToUpper()
    if ($hex.Length -lt 6) { return $null }
    for ($len = [Math]::Min(12, $hex.Length); $len -ge 6; $len--) {
        $k = $hex.Substring(0, $len)
        if ($reg.ContainsKey($k)) {
            return [pscustomobject]@{ Key = $k; Bits = $len * 4; Registrant = $reg[$k] }
        }
    }
    return $null
}

# Does the preset's label corroborate the IEEE registrant?
function Test-Corroborates([string]$label, [string]$registrant) {
    $norm = { param($s) ($s -replace '[^A-Za-z0-9 ]', ' ') -replace '\s+', ' ' }
    $l = (& $norm $label).ToLower()
    $r = (& $norm $registrant).ToLower()

    $noise = @('inc','ltd','llc','corp','corporation','company','co','gmbh','technologies','technology',
               'the','and','of','sa','ag','bv','as','oy','ab','spa','srl','plc','pty','sdn','bhd','usa',
               'international','systems','system','solutions','group','holdings','electronics','communications')
    $rTokens = @(($r -split ' ') | Where-Object { $_.Length -ge 3 -and $_ -notin $noise })
    if ($rTokens.Count -eq 0) { return $false }
    foreach ($t in $rTokens) { if ($l -like "*$t*") { return $true } }
    return $false
}

# ---- audit -------------------------------------------------------------
$base = 'https://raw.githubusercontent.com/CIS-C0/RFSentinel/main/app/src/main/assets/oui_presets'
$rows = @()
$seen = @{}

foreach ($p in $Presets) {
    try { $entries = (Invoke-WebRequest "$base/$p.json" -UseBasicParsing -TimeoutSec 60).Content | ConvertFrom-Json }
    catch { Write-Host "  (skipped $p : $($_.Exception.Message))" -ForegroundColor DarkGray; continue }

    foreach ($e in $entries) {
        # skip the non-MAC rule kinds
        if ($e.prefix -match '^(name|vendor|probe|fp):') { continue }
        $key = "$($e.prefix)|$($e.label)"
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true

        $hit = Resolve-Oui $e.prefix
        $rows += [pscustomobject]@{
            Preset     = $p
            Prefix     = $e.prefix
            Score      = $e.score
            Category   = $e.category
            Label      = $e.label
            Registrant = if ($hit) { $hit.Registrant } else { '<UNREGISTERED>' }
            Bits       = if ($hit) { $hit.Bits } else { 0 }
            Status     = if (-not $hit) { 'NOT-IN-REGISTRY' }
                         elseif (Test-Corroborates $e.label $hit.Registrant) { 'OK' }
                         else { 'REVIEW' }
        }
    }
}

# ---- report ------------------------------------------------------------
$ok     = @($rows | Where-Object Status -eq 'OK')
$review = @($rows | Where-Object Status -eq 'REVIEW')
$miss   = @($rows | Where-Object Status -eq 'NOT-IN-REGISTRY')

Write-Host ""
Write-Host "Audited $($rows.Count) distinct MAC-prefix entries" -ForegroundColor Cyan
Write-Host "  registrant corroborates label : $($ok.Count)" -ForegroundColor Green
Write-Host "  needs review                  : $($review.Count)" -ForegroundColor Yellow
Write-Host "  not found in registry         : $($miss.Count)" -ForegroundColor Red

if ($review.Count) {
    Write-Host ""
    Write-Host "--- REVIEW: label and IEEE registrant do not share a token ---" -ForegroundColor Yellow
    $review | Sort-Object Prefix | ForEach-Object {
        Write-Host ("  {0,-20} /{1,-3} score {2,-4}" -f $_.Prefix, $_.Bits, $_.Score)
        Write-Host ("      label      : {0}" -f $_.Label) -ForegroundColor DarkGray
        Write-Host ("      registrant : {0}" -f $_.Registrant) -ForegroundColor DarkGray
    }
}
if ($miss.Count) {
    Write-Host ""
    Write-Host "--- NOT IN REGISTRY ---" -ForegroundColor Red
    $miss | Sort-Object Prefix | ForEach-Object {
        Write-Host ("  {0,-20} {1}" -f $_.Prefix, $_.Label)
    }
}

$rows | Sort-Object Status, Prefix | Export-Csv -NoTypeInformation -Path "$PSScriptRoot\oui-audit.csv"
Write-Host ""
Write-Host "Full results -> $PSScriptRoot\oui-audit.csv" -ForegroundColor Cyan
