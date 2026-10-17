# Undo-Last-Sort.ps1
# Reverses the most recent real sort run that still has files to put back, using history\sort-log.csv.
#   -DryRun   shows what would be restored and changes nothing.
#   -GiveUp   stop retrying files whose original path is still occupied, so older runs can be undone.
# Exit codes: 0 = ok, 1 = cancelled, refused or nothing to undo.

param([switch]$DryRun, [switch]$GiveUp)

$ToolDir = $PSScriptRoot
$Root    = Split-Path -Parent $ToolDir
$LogFile = Join-Path (Join-Path $ToolDir 'history') 'sort-log.csv'

$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# --- Same safety checks as the sorter ---------------------------------
function Get-Trimmed($p) { if ($p) { $p.TrimEnd('\') } else { '' } }
$rootTrim = Get-Trimmed $Root
$unsafe = @()
$unsafe += Get-Trimmed ([IO.Path]::GetPathRoot($Root))
$unsafe += Get-Trimmed $env:windir
$unsafe += Get-Trimmed $env:ProgramFiles
$unsafe += Get-Trimmed ${env:ProgramFiles(x86)}
$unsafe += Get-Trimmed $env:USERPROFILE
if ($unsafe | Where-Object { $_ -and ($_ -ieq $rootTrim) }) {
    Write-Host "Refusing to run: $Root is a drive root or a protected system folder." -ForegroundColor Red
    exit 1
}

if ($DryRun) {
    Write-Host '--- PREVIEW: nothing will be changed ---' -ForegroundColor Cyan
}
elseif ((Split-Path -Leaf $Root) -cne 'Downloads') {
    Write-Host "Warning: this folder is not called 'Downloads':" -ForegroundColor Yellow
    Write-Host "  $Root" -ForegroundColor Yellow
    $answer = Read-Host "Type YES (capitals) to undo in it, anything else cancels"
    if ($answer -cne 'YES') {
        Write-Host 'Cancelled. Nothing was changed.'
        exit 1
    }
}

# --- Only one sort or undo at a time on this folder --------------------
# (a second double-click, or an undo during a sort, is refused instead of racing).
# A preview only reads, so it is allowed at any time.
if (-not $DryRun) {
    $sha = [Security.Cryptography.SHA1]::Create()
    $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Root.ToLowerInvariant()))) -replace '-', ''
    $script:mutex = New-Object Threading.Mutex($false, "Global\DownloadsSorter_$key")
    $got = $false
    try { $got = $script:mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $got = $true }
    if (-not $got) {
        Write-Host 'Another sort or undo is already running on this folder. Wait for it to finish, then try again.' -ForegroundColor Red
        exit 1
    }
}
# --- Find the latest run that still has files to put back -------------
if (-not (Test-Path -LiteralPath $LogFile)) {
    Write-Host 'No log found. Nothing to undo.'
    exit 1
}
$log = @(Import-Csv -LiteralPath $LogFile -Encoding UTF8)

# A moved file is "settled" once it was restored, or skipped for a reason that
# can never change (file gone, file changed) or that the user gave up on.
# Skips because the original path is occupied stay open and are retried.
$settledPattern = 'no longer at its destination|changed since the sort|identical file already at the original path|given up'
$settled = @{}
foreach ($r in $log) {
    if ($r.Note -notmatch '^undo of run (.+?)(;|$)') { continue }
    $run = $Matches[1]
    if ($r.Action -eq 'UNDONE' -or ($r.Action -eq 'UNDO-SKIPPED' -and $r.Note -match $settledPattern)) {
        $settled["$run|$($r.From)"] = $true
    }
}
$pending = @($log | Where-Object { $_.Action -eq 'MOVED' -and -not $settled.ContainsKey("$($_.Run)|$($_.To)") })
if ($pending.Count -eq 0) {
    Write-Host 'No sort run left to undo.'
    exit 1
}
$target = @($pending | Select-Object -ExpandProperty Run -Unique | Sort-Object)[-1]
$items  = @($pending | Where-Object { $_.Run -eq $target })
[array]::Reverse($items)
Write-Host "Undoing run: $target ($($items.Count) files)"

# --- Undo each file on its own ----------------------------------------
$runStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $inv)
$restored = 0; $skipped = 0; $open = 0

# Log paths are relative to the sorted folder (older logs hold full paths).
function Get-Abs($p) { if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $Root $p } }
function Csv-Field($s) {
    if ($null -eq $s) { return '' }
    $s = [string]$s
    if ($s -match '[",\r\n]|^\s|\s$') { return '"' + $s.Replace('"', '""') + '"' }
    $s
}
# Each result is written to the log straight away, in the same 7-column layout.
function Write-Row($action, $from, $to, $note) {
    if ($DryRun) { return }
    $line = (@($runStamp, $action, $from, $to, $note, '', '') | ForEach-Object { Csv-Field $_ }) -join ','
    # Retry if another program (for example Excel) has the log open.
    for ($i = 0; $i -lt 8; $i++) {
        try { [IO.File]::AppendAllText($LogFile, $line + "`r`n", (New-Object Text.UTF8Encoding($false))); return }
        catch [IO.IOException] { Start-Sleep -Milliseconds 250 }
    }
    Write-Host 'WARNING: could not write to the log (open in another program).' -ForegroundColor Red
}

foreach ($i in $items) {
    $absTo = Get-Abs $i.To; $absFrom = Get-Abs $i.From
    try {
        if (-not (Test-Path -LiteralPath $absTo -PathType Leaf)) { throw 'moved file no longer at its destination' }
        # If the log recorded size and date, make sure it is still the same file.
        if ($i.Size -match '^\d+$' -and $i.Modified -match '^\d+$') {
            $fi = New-Object IO.FileInfo $absTo
            $secs = [long]($fi.LastWriteTimeUtc.Ticks / 10000000)
            if ($fi.Length -ne [long]$i.Size -or [math]::Abs($secs - [long]$i.Modified) -gt 2) {
                throw 'file at the destination has changed since the sort'
            }
        }
        if (Test-Path -LiteralPath $absFrom) {
            # Same size and modified time as the file being restored: nothing to put back.
            $there = New-Object IO.FileInfo $absFrom; $mine = New-Object IO.FileInfo $absTo
            $sa = [long]($there.LastWriteTimeUtc.Ticks / 10000000); $sb = [long]($mine.LastWriteTimeUtc.Ticks / 10000000)
            if ($there.Length -eq $mine.Length -and [math]::Abs($sa - $sb) -le 2) { throw 'identical file already at the original path' }
            throw 'something already exists at the original path'
        }
        if (-not $DryRun) { [IO.File]::Move($absTo, $absFrom) }
        $restored++
        $word = if ($DryRun) { 'WOULD UNDO' } else { 'UNDONE' }
        Write-Host ("{0,-10} {1} -> {2}" -f $word, $i.To, $i.From) -ForegroundColor Green
        Write-Row 'UNDONE' $i.To $i.From "undo of run $target"
    }
    catch {
        $e = $_.Exception; if ($e.InnerException) { $e = $e.InnerException }
        $msg = $e.Message
        $skipped++
        $note = "undo of run $target; $msg"
        if ($GiveUp -and $msg -notmatch $settledPattern) { $note += '; given up' }
        if ($note -notmatch $settledPattern) { $open++ }
        Write-Host ("{0,-10} {1}  ({2})" -f 'SKIPPED', $i.To, $msg) -ForegroundColor DarkYellow
        Write-Row 'UNDO-SKIPPED' $i.To $i.From $note
    }
}

if ($DryRun) {
    Write-Host ("Preview: {0} would be restored, {1} would be skipped." -f $restored, $skipped)
    exit 0
}

Write-Host ("Done. Restored: {0}   Skipped: {1}" -f $restored, $skipped)
if ($open -gt 0) {
    Write-Host "$open file(s) could not be restored because the original path is occupied." -ForegroundColor Yellow
    Write-Host 'Free that path and run the undo again. To stop retrying them and move on to older runs,' -ForegroundColor Yellow
    Write-Host 'run: powershell -ExecutionPolicy Bypass -File Undo-Last-Sort.ps1 -GiveUp' -ForegroundColor Yellow
}
exit 0
