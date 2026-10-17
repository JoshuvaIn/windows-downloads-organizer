# Sort-Downloads.ps1
# Sorts the loose files of the folder ABOVE this ".sort" folder into type folders.
# Run via Sort-Downloads.bat (real run) or Sort-Downloads-Preview.bat (dry run).
# Exit codes: 0 = ok, 1 = cancelled or refused, 2 = at least one file failed.

param([switch]$DryRun)

# ============================== SETTINGS ==============================
# Edit these to change behaviour.

# Folder to sort = the folder that contains this ".sort" folder.
$ToolDir = $PSScriptRoot
$Root    = Split-Path -Parent $ToolDir

# Log file (kept inside the .sort folder).
$HistoryDir = Join-Path $ToolDir 'history'
$LogFile    = Join-Path $HistoryDir 'sort-log.csv'

# Category folder -> extensions. Anything unlisted goes to $DefaultFolder.
$Categories = [ordered]@{
    Images      = '.png .jpg .jpeg .gif .svg .webp .bmp .ico .tif .tiff .heic .avif'
    Videos      = '.mp4 .mkv .mov .avi .wmv .flv .webm .m4v .mpg .mpeg .3gp'
    Audio       = '.mp3 .wav .flac .aac .m4a .ogg .wma .opus'
    Documents   = '.pdf .doc .docx .ppt .pptx .xls .xlsx .csv .txt .rtf .odt .odp .ods .epub'
    MarkItdown  = '.md'
    Archives    = '.zip .rar .7z .tar .gz .tgz .bz2 .xz .iso'
    Installers  = '.exe .msi .msix'
    Code        = '.py .pyw .pyi .js .mjs .cjs .ts .jsx .tsx .vue .svelte .html .htm .css .scss .sass .less .json .jsonc .java .kt .kts .scala .groovy .gradle .c .h .cpp .cc .cxx .hpp .hh .hxx .cs .vb .fs .go .rs .swift .m .mm .dart .rb .php .pl .pm .lua .r .jl .hs .erl .ex .exs .clj .coffee .asm .s .sh .bash .zsh .ps1 .psm1 .psd1 .bat .cmd .vbs .sql .xml .yml .yaml .toml .proto .graphql .tf .ipynb'
}
$DefaultFolder = 'Other'

# Extensions that get a date prefix, for example "261017 report.pdf".
$StampExtensions = '.pdf .doc .docx .ppt .pptx .md'

# Prefix format: 'yyMMdd' (261017) or 'yyMM' (2610).
$StampFormat = 'yyMMdd'

# Which date the prefix uses: 'Earliest' (older of created and modified, best
# after copies, which reset the created date), 'Created' or 'Modified'.
# A date in the future is replaced by today's date.
$StampDateSource = 'Earliest'

# Where identical copies of already-sorted files go (never deleted, undo puts
# them back). Every run checks new loose files against this folder as well as
# the category folders. Set '' to leave duplicates where they are instead.
$DuplicatesFolder = '_copy'

# Folders where a name clash is never resolved by renaming (file is left).
$NeverRenameFolders = 'Videos Code Other'

# Files to ignore, and unfinished-download extensions to ignore.
$SkipNames       = 'desktop.ini'
$SkipExtensions  = '.crdownload .part .tmp .download .opdownload'

# Skip files modified in the last N seconds, so a download in progress is not
# caught. Set 0 to switch off.
$MinAgeSeconds = 120

# Subfolders (directly under the root) whose loose files are ALSO sorted into
# the root's category folders. Empty = subfolders are never entered.
# Example: $IncludeSubfolders = @('Telegram Desktop')
$IncludeSubfolders = @()

# Tidy file names before moving: trim spaces around the name and before the
# extension ("Report .pdf" -> "Report.pdf"). Off by default.
$TidyNames = $false

# Extra duplicate check: treat a file as a duplicate if any file in the
# destination folder has the same size and the same SHA-256 hash, whatever its
# name or date. Catches re-downloads such as "Report (1).pdf". Slower on big
# files, so it is off by default.
$HashCheck = $false
# ======================================================================

$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# --- Refuse unsafe roots ---------------------------------------------
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

# --- Safety prompt (real run only, and only if folder is not 'Downloads')
if ($DryRun) {
    Write-Host '--- PREVIEW: nothing will be changed ---' -ForegroundColor Cyan
}
elseif ((Split-Path -Leaf $Root) -cne 'Downloads') {
    Write-Host "Warning: this folder is not called 'Downloads':" -ForegroundColor Yellow
    Write-Host "  $Root" -ForegroundColor Yellow
    $answer = Read-Host "Type YES (capitals) to sort it, anything else cancels"
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
# --- Lookup tables ----------------------------------------------------
$extMap = @{}
foreach ($cat in $Categories.Keys) {
    foreach ($e in ($Categories[$cat] -split '\s+' | Where-Object { $_ })) { $extMap[$e] = $cat }
}
$stampSet  = $StampExtensions   -split '\s+' | Where-Object { $_ }
$skipExt   = $SkipExtensions    -split '\s+' | Where-Object { $_ }
$noRename  = $NeverRenameFolders -split '\s+' | Where-Object { $_ }
$catNames  = @($Categories.Keys) + $DefaultFolder
if ($DuplicatesFolder) { $catNames += $DuplicatesFolder }
$copyDir   = if ($DuplicatesFolder) { Join-Path $Root $DuplicatesFolder } else { '' }
# A name already starts with a stamp if it begins YYMM or YYMMDD plus a space.
# Both lengths count, so older YYMM names are not stamped a second time.
$stampPattern = '^\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])? '

# --- Collect files (no hidden/system files) ---------------------------
$now = Get-Date
$scanDirs = @($Root)
foreach ($sub in $IncludeSubfolders) {
    $p = Join-Path $Root $sub
    if (($catNames -contains $sub) -or $sub -eq '.sort') { continue }
    if (Test-Path -LiteralPath $p -PathType Container) { $scanDirs += $p }
}
$tooNew = 0
$files = @(foreach ($dir in $scanDirs) {
    foreach ($x in (Get-ChildItem -LiteralPath $dir -File)) {
        if ($SkipNames -contains $x.Name.ToLowerInvariant()) { continue }
        if ($skipExt -contains $x.Extension.ToLowerInvariant()) { continue }
        # Only files changed in the last N seconds count as "too new"; a date in the future (clock skew) does not.
        $age = ($now - $x.LastWriteTime).TotalSeconds
        if ($MinAgeSeconds -gt 0 -and $age -ge 0 -and $age -lt $MinAgeSeconds) { $tooNew++; continue }
        $x
    }
})

if ($tooNew -gt 0) {
    Write-Host "Skipped $tooNew file(s) changed in the last $MinAgeSeconds seconds (may still be downloading)." -ForegroundColor DarkYellow
}
if ($files.Count -eq 0) {
    Write-Host 'Nothing to sort.'
    exit 0
}

# --- Helpers ----------------------------------------------------------
$runStamp = $now.ToString('yyyy-MM-dd HH:mm:ss', $inv)
$planned  = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$attention = New-Object 'System.Collections.Generic.List[string]'

function Test-Taken($path) { $planned.Contains($path) -or (Test-Path -LiteralPath $path) }

function Get-ErrorText($err) {
    $e = $err.Exception
    if ($e.InnerException) { $e = $e.InnerException }
    $e.Message
}

# Date used for the prefix, per $StampDateSource. Never later than now.
function Get-StampDate($file) {
    switch ($StampDateSource) {
        'Created'  { $d = $file.CreationTime }
        'Modified' { $d = $file.LastWriteTime }
        default    { $d = if ($file.CreationTime -lt $file.LastWriteTime) { $file.CreationTime } else { $file.LastWriteTime } }
    }
    if ($d -gt $now) { $d = $now }
    $d
}

function Get-CleanName($name) {
    if (-not $TidyNames) { return $name }
    $ext  = [IO.Path]::GetExtension($name)
    $base = ([IO.Path]::GetFileNameWithoutExtension($name)).Trim() -replace '\s{2,}', ' '
    if ($base -eq '') { return $name }
    $base + $ext
}

function Get-Secs($t) { [long]($t.ToUniversalTime().Ticks / 10000000) }

# --- Duplicate detection ----------------------------------------------
# Each destination folder is listed once and indexed by file size, so a check
# only compares files of the same size (fast even with thousands of files).
$dirIndex = @{}
function Get-DirIndex($dir) {
    if (-not $dirIndex.ContainsKey($dir)) {
        $idx = @{}
        if (Test-Path -LiteralPath $dir -PathType Container) {
            foreach ($p in [IO.Directory]::EnumerateFiles($dir)) {
                $fi = New-Object IO.FileInfo $p
                $k = [string]$fi.Length
                if (-not $idx.ContainsKey($k)) { $idx[$k] = New-Object 'System.Collections.Generic.List[object]' }
                $idx[$k].Add([pscustomobject]@{ Name = $fi.Name; Path = $p; Secs = (Get-Secs $fi.LastWriteTime); Hash = $null })
            }
        }
        $dirIndex[$dir] = $idx
    }
    , $dirIndex[$dir]
}
function Get-Hash($path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }

# Identical = same size AND (same name, or same name with a date prefix, and a
# modified time within 2 seconds) OR (with $HashCheck) the same SHA-256 hash.
function Find-Duplicate($dir, $file, $cleanName) {
    $idx = Get-DirIndex $dir
    $bucket = $idx[[string]$file.Length]
    if (-not $bucket) { return $null }
    $secs = Get-Secs $file.LastWriteTime
    $suffix = ' ' + $cleanName
    foreach ($e in $bucket) {
        if ([math]::Abs($e.Secs - $secs) -gt 2) { continue }
        if ($e.Name -ieq $cleanName) { return $e.Name }
        if ($e.Name.Length -gt $suffix.Length -and $e.Name.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase) -and
            (($e.Name.Substring(0, $e.Name.Length - $suffix.Length) + ' ') -match $stampPattern)) { return $e.Name }
    }
    if ($HashCheck -and $file.Length -gt 0) {
        $mine = $null
        foreach ($e in $bucket) {
            if ($null -eq $mine) { $mine = Get-Hash $file.FullName }
            if ($null -eq $e.Hash) { $e.Hash = Get-Hash $e.Path }
            if ($e.Hash -eq $mine) { return $e.Name }
        }
    }
    $null
}
function Add-ToIndex($dir, $name, $path, $file) {
    $idx = Get-DirIndex $dir
    $k = [string]$file.Length
    if (-not $idx.ContainsKey($k)) { $idx[$k] = New-Object 'System.Collections.Generic.List[object]' }
    $idx[$k].Add([pscustomobject]@{ Name = $name; Path = $path; Secs = (Get-Secs $file.LastWriteTime); Hash = $null })
}

# Preview only: is the file in use? (a real move would then fail)
function Test-Locked($path) {
    try {
        $s = [IO.File]::Open($path, 'Open', 'Read', 'None'); $s.Close(); $false
    } catch { $true }
}

# --- Log: one row is written as soon as each file is handled ----------
# Paths are relative to the sorted folder, so undo survives a move or rename.
$LogHeader = 'Run,Action,From,To,Note,Size,Modified'
$logReady  = $false
$lastState = @{}      # From -> "Action|Note", so the same LEFT/FAILED is not logged every run

function Get-Rel($path) {
    if ($path -and $path.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { return $path.Substring($Root.Length + 1) }
    $path
}
function Csv-Field($s) {
    if ($null -eq $s) { return '' }
    $s = [string]$s
    if ($s -match '[",\r\n]|^\s|\s$') { return '"' + $s.Replace('"', '""') + '"' }
    $s
}
# Append to the log. If something else has the file open (for example Excel), wait
# and retry; if it stays locked, keep the rows and try again, so a run is never
# stopped by the log. A warning is shown at the end if rows could not be saved.
$pendingLog = New-Object 'System.Collections.Generic.List[string]'
function Flush-Log {
    if ($pendingLog.Count -eq 0) { return $true }
    $text = ($pendingLog -join '')
    for ($i = 0; $i -lt 8; $i++) {
        try { [IO.File]::AppendAllText($LogFile, $text, (New-Object Text.UTF8Encoding($false))); $pendingLog.Clear(); return $true }
        catch [IO.IOException] { Start-Sleep -Milliseconds 250 }
    }
    return $false
}
function Append-Log($line) { $pendingLog.Add($line); [void](Flush-Log) }
function Initialize-Log {
    if ($script:logReady) { return }
    [IO.Directory]::CreateDirectory($HistoryDir) | Out-Null
    if (Test-Path -LiteralPath $LogFile) {
        $first = Get-Content -LiteralPath $LogFile -TotalCount 1 -Encoding UTF8
        if (($first -replace '^\xEF\xBB\xBF|^?', '') -ne $LogHeader) {
            # Log from an older version of the tool: keep it, start a new one.
            $old = Join-Path $HistoryDir ('sort-log-old-' + (Get-Date).ToString('yyyyMMdd-HHmmss', $inv) + '.csv')
            Move-Item -LiteralPath $LogFile -Destination $old
        }
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        [IO.File]::WriteAllText($LogFile, $LogHeader + "`r`n", (New-Object Text.UTF8Encoding($true)))   # BOM for Excel
    }
    $script:logReady = $true
}
function Load-LastState {
    if (-not (Test-Path -LiteralPath $LogFile)) { return }
    $first = Get-Content -LiteralPath $LogFile -TotalCount 1 -Encoding UTF8
    if (($first -replace '^\xEF\xBB\xBF|^?', '') -ne $LogHeader) { return }
    foreach ($r in (Import-Csv -LiteralPath $LogFile -Encoding UTF8)) {
        if ($r.Action -in 'MOVED', 'LEFT', 'FAILED') { $lastState[$r.From] = "$($r.Action)|$($r.Note)" }
    }
}
function Write-Log($action, $from, $to, $note, $size, $mod) {
    if ($DryRun) { return }
    $from = Get-Rel $from; $to = Get-Rel $to
    if ($action -ne 'MOVED') {
        # Do not repeat an identical LEFT/FAILED entry run after run.
        if ($lastState[$from] -eq "$action|$note") { return }
    }
    $lastState[$from] = "$action|$note"
    Initialize-Log
    $line = (@($runStamp, $action, $from, $to, $note, $size, $mod) | ForEach-Object { Csv-Field $_ }) -join ','
    Append-Log ($line + "`r`n")
}
if (-not $DryRun) { Load-LastState }

$moved = 0; $left = 0; $failed = 0; $dups = 0

# --- Main loop: each file is decided and moved on its own -------------
foreach ($f in $files) {
    $ext    = $f.Extension.ToLowerInvariant()
    $folder = if ($extMap.ContainsKey($ext)) { $extMap[$ext] } else { $DefaultFolder }
    $clean  = Get-CleanName $f.Name
    $yymm   = (Get-StampDate $f).ToString($StampFormat, $inv)

    # Naming: stamp PDF/DOC/DOCX/PPT/PPTX/MD unless already stamped.
    $hadStamp = $clean -match $stampPattern
    $newName  = $clean
    $justStamped = $false
    if (($stampSet -contains $ext) -and -not $hadStamp) {
        $newName = "$yymm $clean"
        $justStamped = $true
    }

    $destDir = Join-Path $Root $folder
    $target  = Join-Path $destDir $newName
    $shown   = "$folder\$newName"

    try {
        # A loose file with the same name as a category folder blocks that
        # folder, so it is never moved (otherwise results would depend on order).
        if ($f.DirectoryName -ieq $Root -and ($catNames -icontains $f.Name)) {
            throw "A file named '$($f.Name)' has the same name as a category folder. Rename it."
        }
        # A loose FILE standing where a category folder should be.
        if (Test-Path -LiteralPath $destDir -PathType Leaf) {
            throw "A file named '$folder' is in the way of the category folder."
        }

        # Identical copy already sorted (in its category folder) or already in the
        # duplicates folder? Then this loose file is a duplicate.
        $dup = Find-Duplicate $destDir $f $clean
        $dupWhere = $folder
        if (-not $dup -and $copyDir) { $dup = Find-Duplicate $copyDir $f $clean; $dupWhere = $DuplicatesFolder }
        $isDup = $false
        $moveNote = ''
        if ($dup) {
            if (-not $copyDir) {
                # No duplicates folder configured: leave the file where it is.
                $left++
                $reason = "identical file already in destination: $dup"
                Write-Host ("{0,-10} {1} -> {2}  ({3})" -f 'LEFT', $f.Name, $shown, $reason) -ForegroundColor DarkYellow
                $attention.Add("$($f.Name): $reason")
                Write-Log 'LEFT' $f.FullName '' $reason '' ''
                continue
            }
            # Move it into the duplicates folder under its own name (no date prefix).
            $isDup = $true
            $moveNote = "duplicate of $dupWhere\$dup"
            $destDir = $copyDir
            $newName = $clean
            $target  = Join-Path $destDir $newName
            if (Test-Path -LiteralPath $destDir -PathType Leaf) { throw "A file named '$DuplicatesFolder' is in the way of the duplicates folder." }
            if (Test-Taken $target) {
                # Same name already in the duplicates folder: one retry with the date prefix, else leave it.
                $target = Join-Path $destDir "$yymm $clean"; $newName = "$yymm $clean"
                if (Test-Taken $target) {
                    $left++
                    $reason = "identical file already in $DuplicatesFolder (same name taken): $dup"
                    Write-Host ("{0,-10} {1}  ({2})" -f 'LEFT', $f.Name, $reason) -ForegroundColor DarkYellow
                    $attention.Add("$($f.Name): $reason")
                    Write-Log 'LEFT' $f.FullName '' $reason '' ''
                    continue
                }
            }
            $shown = "$DuplicatesFolder\$newName"
        }

        # Name clash rules (the existing file is a different file).
        if (-not $isDup -and (Test-Taken $target)) {
            $leave = ($noRename -contains $folder) -or $justStamped -or $hadStamp
            if (-not $leave) {
                # One retry with the date prefix.
                $alt = Join-Path $destDir "$yymm $clean"
                if (Test-Taken $alt) { $leave = $true }
                else { $target = $alt; $newName = "$yymm $clean"; $shown = "$folder\$newName" }
            }
            if ($leave) {
                $left++
                $reason = 'a different file with that name already exists in destination'
                Write-Host ("{0,-10} {1} -> {2}  ({3})" -f 'LEFT', $f.Name, $shown, $reason) -ForegroundColor DarkYellow
                $attention.Add("$($f.Name): $reason")
                Write-Log 'LEFT' $f.FullName '' 'name already exists in destination' '' ''
                continue
            }
        }

        if ($target.Length -ge 260) { throw 'Destination path is too long for Windows (260 characters).' }

        if ($DryRun) {
            if (Test-Locked $f.FullName) { throw 'File appears to be in use by another program.' }
            $planned.Add($target) | Out-Null
            Add-ToIndex $destDir $newName $target $f
            $moved++
            if ($isDup) { $dups++ }
            $extra = if ($isDup) { "  ($moveNote)" } else { '' }
            Write-Host ("{0,-10} {1} -> {2}{3}" -f 'WOULD MOVE', $f.Name, $shown, $extra) -ForegroundColor $(if ($isDup) { 'Cyan' } else { 'Green' })
        }
        else {
            $size = $f.Length; $mod = Get-Secs $f.LastWriteTime
            [IO.Directory]::CreateDirectory($destDir) | Out-Null
            [IO.File]::Move($f.FullName, $target)      # throws if the target exists: never overwrites
            $planned.Add($target) | Out-Null
            Add-ToIndex $destDir $newName $target $f
            $moved++
            if ($isDup) { $dups++ }
            $extra = if ($isDup) { "  ($moveNote)" } else { '' }
            Write-Host ("{0,-10} {1} -> {2}{3}" -f 'MOVED', $f.Name, $shown, $extra) -ForegroundColor $(if ($isDup) { 'Cyan' } else { 'Green' })
            Write-Log 'MOVED' $f.FullName $target $moveNote $size $mod
        }
    }
    catch {
        $failed++
        $msg = Get-ErrorText $_
        $attention.Add("$($f.Name): $msg")
        Write-Host ("{0,-10} {1} -> {2}  ({3})" -f 'FAILED', $f.Name, $shown, $msg) -ForegroundColor Red
        Write-Log 'FAILED' $f.FullName $target $msg '' ''
    }
}

# --- Summary ----------------------------------------------------------
if ($attention.Count -gt 0) {
    Write-Host ''
    Write-Host 'Needs your attention (left in the folder):' -ForegroundColor Yellow
    foreach ($a in $attention) { Write-Host "  $a" -ForegroundColor Yellow }
    Write-Host ''
}

if ($DryRun) {
    Write-Host ("Preview: {0} would move ({1} of them duplicates), {2} would stay." -f $moved, $dups, ($left + $failed))
    exit 0
}

if (-not (Flush-Log)) { Write-Host "WARNING: the log could not be saved because it is open in another program: $LogFile" -ForegroundColor Red; Write-Host ("         {0} row(s) were not written. Close the file and sort again to be safe." -f $pendingLog.Count) -ForegroundColor Red }
Write-Host ("Done. Moved: {0} (duplicates: {1})   Left in place: {2}   Failed: {3}" -f $moved, $dups, $left, $failed)
if (Test-Path -LiteralPath $LogFile) { Write-Host "Log: $LogFile" }
if ($failed -gt 0) { exit 2 }
exit 0
