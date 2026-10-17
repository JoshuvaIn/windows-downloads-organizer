# Smoke-Test.ps1
# A short check you can run to see the tool work. It builds a throwaway folder in your
# temporary files, runs the tool through preview, sort, a second run, a duplicate, a
# name clash, a locked file, a refused second copy and undo, then deletes the folder.
# It never touches your own folders.
#
# Run from the repository folder:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\Smoke-Test.ps1

param([string]$ToolDir = (Join-Path (Split-Path -Parent $PSScriptRoot) '.sort'))

$ErrorActionPreference = 'Stop'
$failures = 0
function Check($name, $ok) {
    if ($ok) { Write-Host "  PASS  $name" -ForegroundColor Green }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:failures++ }
}

if (-not (Test-Path -LiteralPath (Join-Path $ToolDir 'Sort-Downloads.ps1'))) { throw "Cannot find the tool in $ToolDir" }

# The folder is called Downloads so the tool does not ask for confirmation.
$base = Join-Path $env:TEMP ('sorter-smoke-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$root = Join-Path $base 'Downloads'
[void][IO.Directory]::CreateDirectory($root)
Copy-Item -LiteralPath $ToolDir -Destination (Join-Path $root '.sort') -Recurse

function Run($script, $extra = @()) {
    $o = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root ".sort\$script") @extra 2>&1 | Out-String
    [pscustomobject]@{ Out = $o; Exit = $LASTEXITCODE }
}
function Make($name, $text, $daysOld) {
    $p = Join-Path $root $name
    [IO.File]::WriteAllText($p, $text)
    $d = (Get-Date).AddDays(-$daysOld)
    [IO.File]::SetLastWriteTime($p, $d); [IO.File]::SetCreationTime($p, $d)
    $d
}
function Exists($rel) { Test-Path -LiteralPath (Join-Path $root $rel) }
function Loose { @(Get-ChildItem -LiteralPath $root -File -Force | ? { $_.Name -notlike '.sort*' }).Count }

try {
    Write-Host 'Building a demo folder...'
    $dPdf = Make 'invoice.pdf' 'pdf one' 40
    Make 'photo.jpg' 'jpg' 20 | Out-Null
    Make 'song.mp3' 'mp3' 20 | Out-Null
    Make 'Main.java' 'java' 5 | Out-Null
    Make 'App.cs' 'csharp' 5 | Out-Null
    Make 'page.html' 'html' 5 | Out-Null
    Make 'notes.md' 'md' 12 | Out-Null
    Make 'setup.exe' 'exe' 9 | Out-Null
    Make 'mystery.xyz' 'xyz' 9 | Out-Null
    Make 'half.crdownload' 'partial' 9 | Out-Null          # unfinished download: must be left alone
    $hidden = Make 'secret.txt' 'hidden' 9; (Get-Item -LiteralPath (Join-Path $root 'secret.txt')).Attributes = 'Hidden'
    $stamp = $dPdf.ToString('yyMMdd')

    Write-Host 'Preview'
    $r = Run 'Sort-Downloads.ps1' @('-DryRun')
    Check 'preview exits cleanly' ($r.Exit -eq 0)
    Check 'preview lists files as WOULD MOVE' ($r.Out -match 'WOULD MOVE')
    Check 'preview changes nothing' ((Loose) -eq 11 -and -not (Exists 'Images'))
    Check 'preview writes no log' (-not (Exists '.sort\history'))

    Write-Host 'First sort'
    $r = Run 'Sort-Downloads.ps1'
    Check 'sort exits cleanly' ($r.Exit -eq 0)
    Check 'PDF is dated from its age and put in Documents' (Exists "Documents\$stamp invoice.pdf")
    Check 'photo goes to Images' (Exists 'Images\photo.jpg')
    Check 'audio goes to Audio' (Exists 'Audio\song.mp3')
    Check 'Java, C# and HTML all go to Code' ((Exists 'Code\Main.java') -and (Exists 'Code\App.cs') -and (Exists 'Code\page.html'))
    Check 'Markdown goes to MarkItdown with a date' (@(Get-ChildItem (Join-Path $root 'MarkItdown') -File).Name -match '^\d{6} notes\.md$')
    Check 'installer goes to Installers' (Exists 'Installers\setup.exe')
    Check 'unknown type goes to Other' (Exists 'Other\mystery.xyz')
    Check 'unfinished download and hidden file are left alone' ((Exists 'half.crdownload') -and (Exists 'secret.txt'))
    Check 'a log was written' (Exists '.sort\history\sort-log.csv')

    Write-Host 'Second run'
    $r = Run 'Sort-Downloads.ps1'
    Check 'second run has nothing new to move' ($r.Out -match 'Moved: 0' -or $r.Out -match 'Nothing to sort')

    Write-Host 'Duplicate and name clash'
    $src = Join-Path $root "Documents\$stamp invoice.pdf"
    Copy-Item -LiteralPath $src -Destination (Join-Path $root 'invoice.pdf')
    [IO.File]::SetLastWriteTime((Join-Path $root 'invoice.pdf'), (Get-Item -LiteralPath $src).LastWriteTime)
    $r = Run 'Sort-Downloads.ps1'
    Check 'an identical copy goes to _copy' (Exists '_copy\invoice.pdf')
    Check 'the original was not touched' (Exists "Documents\$stamp invoice.pdf")
    Make 'photo.jpg' 'a different photo with the same name' 3 | Out-Null
    $r = Run 'Sort-Downloads.ps1'
    Check 'a different file with the same name does not overwrite' ((Get-Content -LiteralPath (Join-Path $root 'Images\photo.jpg')) -eq 'jpg')
    Check 'the different file is kept (with a date prefix)' (@(Get-ChildItem (Join-Path $root 'Images') -File).Count -eq 2)

    Write-Host 'Locked file'
    Make 'locked.pdf' 'in use' 15 | Out-Null
    $fs = [IO.File]::Open((Join-Path $root 'locked.pdf'), 'Open', 'ReadWrite', 'None')
    Make 'free.pdf' 'free' 15 | Out-Null
    $r = Run 'Sort-Downloads.ps1'
    $fs.Close()
    Check 'locked file is reported as FAILED and left in place' ($r.Out -match 'FAILED' -and (Exists 'locked.pdf'))
    Check 'the other file is still sorted' ((@(Get-ChildItem (Join-Path $root 'Documents') -File).Name -match 'free\.pdf').Count -ge 1)
    Check 'exit code says something failed' ($r.Exit -eq 2)

    Write-Host 'Only one at a time'
    $sha = [Security.Cryptography.SHA1]::Create()
    $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($root.ToLowerInvariant()))) -replace '-', ''
    $mutex = New-Object Threading.Mutex($false, "Global\DownloadsSorter_$key")
    [void]$mutex.WaitOne(0)
    $r = Run 'Sort-Downloads.ps1'
    $mutex.ReleaseMutex(); $mutex.Dispose()
    Check 'a second sort is refused while one is running' ($r.Out -match 'Another sort or undo is already running' -and $r.Exit -eq 1)

    Write-Host 'Undo'
    $before = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | ? { $_.FullName -notlike '*\.sort\*' }).Count
    for ($i = 0; $i -lt 6; $i++) { $r = Run 'Undo-Last-Sort.ps1'; if ($r.Out -match 'No sort run left') { break } }
    Check 'undo puts the original names back' ((Exists 'invoice.pdf') -and (Exists 'photo.jpg') -and (Exists 'Main.java') -and (Exists 'notes.md') -and (Exists 'song.mp3'))
    $after = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | ? { $_.FullName -notlike '*\.sort\*' }).Count
    Check 'undo loses no files' ($before -eq $after)
}
finally {
    if ($fs) { $fs.Close() }
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($failures -eq 0) { Write-Host 'All checks passed.' -ForegroundColor Green } else { Write-Host "$failures check(s) failed." -ForegroundColor Red }
exit $failures
