> **Historical document.** This is the first design brief, kept for the record. Sections 15 to 18 at the end record later changes and override earlier sections where they disagree. For the current behaviour read [How it works](../HOW-IT-WORKS.md).

# Build prompt: One-click Downloads sorter for Windows

Paste everything below into Claude Code CLI. It is a full specification. Do not write any code until you have read it all, replied with a short build plan and a list of any questions, and I have approved the plan.

---

## 1. Goal

I use a Windows laptop. My Downloads folder keeps filling with mixed files (movies, MP3s, zips, Word, PowerPoint, PDF, Markdown, installers, images, code and anything else). I want to double-click one file and have every loose file sorted into type folders. I want to be able to do this again at any time, for example a month later, and have it only deal with whatever has piled up since.

It must be safe: preview first, never overwrite, never touch what is already sorted, and keep a log that lets me reverse a run.

## 2. Environment and constraints

- Windows 10 or 11, using Windows PowerShell 5.1 (preinstalled). Must also work on PowerShell 7.
- No installs and no third-party modules. No admin rights.
- Launched by double-clicking a .bat file. The .bat is only a thin launcher; all logic lives in a .ps1 beside it.
- The .ps1 must be plain ASCII (no smart quotes or special characters in the source) with CRLF line endings. File names it processes can be any Unicode text (Tamil, Chinese, accented, emoji).
- Every file operation uses literal paths, so names containing `[ ] % ^ ! & ' ,` work.
- Works wherever the folder lives and whatever the user's name is. Never hard-code a path; the folder to sort is the folder the script sits in.
- Use British English in all messages.

## 3. Deliverables

Put these in one folder, ready to copy into Downloads:

| File | Purpose |
|---|---|
| `Sort-Downloads.bat` | Double-click launcher, real run. Runs the .ps1 with execution policy bypassed for that process only, then pauses so the window stays open. |
| `Sort-Downloads-Preview.bat` | Same launcher, but passes the dry-run switch. |
| `Sort-Downloads.ps1` | All the logic. |
| `Undo-Last-Sort.bat` | Launcher for undo (see section 10). |
| `Undo-Last-Sort.ps1` | Reverses the most recent real run using the log. |
| `README.md` | Short usage notes, the rules table and the log format. |

## 4. Folder structure

The script sits inside the folder to sort. Before the first run:

```
Downloads\
    holiday.mp4
    song.mp3
    report.pdf
    budget.xlsx
    setup.exe
    photo.jpg
    notes.md
    script.py
    archive.zip
    mystery.xyz
    .hiddenfile           (hidden: never touched)
    Sort-Downloads.bat
    Sort-Downloads-Preview.bat
    Sort-Downloads.ps1
    Undo-Last-Sort.bat
    Undo-Last-Sort.ps1
    README.md
    OldStuff\             (existing subfolder: never entered, never touched)
        anything.pdf
```

After a real run:

```
Downloads\
    Images\       photo.jpg
    Videos\       holiday.mp4
    Audio\        song.mp3
    Documents\    2610 report.pdf     (renamed: created date prefix)
                  budget.xlsx         (type moved, name unchanged)
    MarkItdown\   2610 notes.md       (renamed: created date prefix)
    Archives\     archive.zip
    Installers\   setup.exe
    Code\         script.py
    Other\        mystery.xyz
    SortLog\     sort-log.csv        (created on the first real run)
    OldStuff\     anything.pdf        (untouched)
    .hiddenfile                       (untouched)
    (the launcher and script files stay where they are)
```

Rules for the structure:

- Category folders are created only when a file needs to go in them. Do not create empty folders.
- Existing category folders are reused on later runs, with their current contents left alone.
- Folders directly under the root are never entered and never moved, including `SortLog` and any the user created.
- Nothing is ever moved into a sub-subfolder (no year or month subfolders in this version).

## 5. What counts as a file to process

Process a file only if all of these are true:

- It sits directly in the root folder (no recursion).
- It is not hidden and not a system file. Use the default behaviour of listing files without the force option, which excludes both.
- It is not one of the tool's own files: anything whose name starts with `Sort-Downloads`, `Undo-Last-Sort`, or is `README.md` or `desktop.ini`.
- Its extension is not an unfinished-download marker: `.crdownload`, `.part`, `.tmp`, `.download`, `.opdownload`.

Optional safety, off by default but configurable at the top of the script: skip files modified in the last N seconds (default 0) so a download in progress with a normal extension is not caught.

## 6. Categories (extension to folder)

All folder names the tool creates use a capital first letter (for example `Images`, `Documents`, `MarkItdown`, `SortLog`). Markdown files get their own `MarkItdown` folder instead of going into Documents.

Match extensions case-insensitively. A file with no extension, or an unlisted extension, goes to `Other`. Keep this table as a single editable block at the top of the script.

| Folder | Extensions |
|---|---|
| Images | .png .jpg .jpeg .gif .svg .webp .bmp .ico .tif .tiff .heic .avif |
| Videos | .mp4 .mkv .mov .avi .wmv .flv .webm .m4v .mpg .mpeg .3gp |
| Audio | .mp3 .wav .flac .aac .m4a .ogg .wma .opus |
| Documents | .pdf .doc .docx .ppt .pptx .xls .xlsx .csv .txt .rtf .odt .odp .ods .epub |
| MarkItdown | .md |
| Archives | .zip .rar .7z .tar .gz .tgz .bz2 .xz .iso |
| Installers | .exe .msi .msix |
| Code | .py .js .ts .jsx .tsx .html .htm .css .scss .json .java .c .cpp .h .hpp .cs .go .rs .sh .ps1 .bat .cmd .php .sql .xml .yml .yaml .ipynb .rb .swift .kt .lua .r .vbs |
| Other | everything else |

Note: the tool's own .bat and .ps1 files are excluded by section 5, so they never move into Code. Any other .bat or .ps1 the user downloads goes to Code.

## 7. Naming rules

### 7.1 Stamped types: PDF, DOC, DOCX, PPT, PPTX, MD

- New name format: `YYMM`, one normal space, the original file name. Example: `report.pdf` created in October 2026 becomes `2610 report.pdf`. No hyphen, no underscore.
- YYMM comes from the file's created date (CreationTime), not the modified date and not the day of the run. Format it with the invariant culture so it is always Gregorian digits.
- Do not stamp a name that already begins with a valid stamp. A valid stamp is two digits, then a month 01 to 12, then a space (pattern `^\d{2}(0[1-9]|1[0-2]) `). So `2610 report.pdf` is left as is, but `2024 Budget.pdf` is stamped because 24 is not a month.
- Only these six extensions are stamped (MD is the MarkItdown folder, so every Markdown file is stamped, e.g. `notes.md` becomes `2610 notes.md`). TXT, CSV, XLS, XLSX and the rest of Documents keep their names.

### 7.2 Every other type

Keep the original name.

## 8. Name clash rules

Evaluate after working out the intended target name:

1. If the target does not exist, move.
2. If it exists and the category is Videos, Code or Other: leave the file in the root. Never rename these. Log as LEFT.
3. If it exists and the file was already given a stamp in 7.1: leave it (the stamped name is taken). Log as LEFT.
4. If it exists and the file already starts with a valid stamp: leave it. Log as LEFT.
5. Otherwise (Images, Audio, Archives, Installers, and the unstamped Documents types): try once with the `YYMM ` prefix from the created date. If that name is also taken, leave it. Log as LEFT.
6. Never overwrite anything, never delete anything, never add a counter like `(1)`.

Several files in one run can resolve to the same target. Check for existence immediately before each move, not from a list built in advance.

## 9. Behaviour details

### 9.1 Dry run (preview)

- Prints exactly what a real run would do. Creates no folders, moves no files, writes no log.
- One line per file in the same format as the real run, but starting `WOULD MOVE` or `LEFT`.
- Ends with a summary line: `Preview: X would move, Y would stay.`
- Banner on the first line: `--- PREVIEW: nothing will be changed ---`.

### 9.2 Real run

- For each file, one line on screen: `MOVED`, `LEFT` or `FAILED`, then the original name, an arrow and `Folder\NewName`. Colours: green for MOVED, dark yellow for LEFT, red for FAILED.
- Each file succeeds or fails independently. A locked or in-use file produces FAILED with the Windows error message, and the loop carries on. The moved count only includes confirmed successes.
- Final summary: `Done. Moved: X   Left in place: Y   Failed: Z` and the path of the log file.
- Exit code 0 if there were no failures, 1 if the user cancelled the safety prompt, 2 if any file failed.

### 9.3 Safety prompt

- If the root folder's name is not exactly `Downloads`, show a yellow warning with the full path and ask the user to type `YES` (case-sensitive). Anything else cancels with no changes.
- Does not apply to preview mode.
- Also refuse to run, with a clear message, if the root is a drive root (for example `C:\`) or is the Windows, Program Files or user profile root folder.

### 9.4 Window behaviour

- The .bat files keep the window open with a pause so the user can read the result.
- No other prompts or questions during a normal run in the Downloads folder.

## 10. Log specification

### 10.1 Location and format

- File: `SortLog\sort-log.csv`, directly under the sorted folder.
- Created on the first real run that has something to record. Append on later runs; never overwrite or rotate.
- UTF-8 with header row, comma-separated, standard CSV quoting, Windows line endings.
- Only real runs write to it. Preview never does.

### 10.2 Columns

| Column | Content |
|---|---|
| Run | Timestamp when the run started, `yyyy-MM-dd HH:mm:ss`, same value for every row of one run |
| Action | `MOVED`, `LEFT` or `FAILED` |
| From | Full original path |
| To | Full destination path (empty for LEFT) |
| Note | Reason text: empty for MOVED, `name already exists in destination` for LEFT, the error message for FAILED |

### 10.3 Example

```
Run,Action,From,To,Note
2026-10-17 21:04:11,MOVED,C:\Users\dom\Downloads\report.pdf,C:\Users\dom\Downloads\Documents\2610 report.pdf,
2026-10-17 21:04:11,MOVED,C:\Users\dom\Downloads\photo.jpg,C:\Users\dom\Downloads\Images\photo.jpg,
2026-10-17 21:04:11,LEFT,C:\Users\dom\Downloads\movie.mp4,,name already exists in destination
2026-10-17 21:04:11,FAILED,C:\Users\dom\Downloads\open.docx,C:\Users\dom\Downloads\Documents\2610 open.docx,The process cannot access the file because it is being used by another process.
```

### 10.4 Undo

`Undo-Last-Sort.ps1` reverses the most recent real run:

- Find the latest `Run` value in the log and take its MOVED rows only.
- Process them in reverse order. For each, if the file still exists at `To` and nothing exists at `From`, move it back to `From`. Restore the original name (the `From` path already carries it).
- If either condition fails, skip the row and report it.
- After undo, append rows to the same log with Action `UNDONE` or `UNDO-SKIPPED` and a fresh Run timestamp, so a second undo cannot reverse the same run twice (it must only target the latest run that has no UNDONE rows).
- Never delete category folders, even if they become empty.
- Supports the same safety prompt as the sorter, and a `-DryRun` switch.

## 11. Edge cases the build must handle

- Files with no extension, with multiple dots (`archive.tar.gz` uses the last extension `.gz`), or a leading dot only.
- Upper-case extensions (`PHOTO.JPG`).
- Names with spaces, brackets, apostrophes, ampersands, percent signs, exclamation marks, commas and non-Latin characters.
- Very long paths: if the target path would exceed Windows limits, log as FAILED and carry on.
- A loose file whose name equals a category folder name (for example a file called `Images` with no extension): treat as FAILED for that file, no crash.
- The category folder exists but is read-only or in use: FAILED for that file only.
- Empty root (nothing to do): print `Nothing to sort.`, do not create the log or any folder.
- Running twice in a row: the second run moves nothing and reports `Moved: 0`.
- The root contains thousands of files: stays responsive, no per-file process launches, no building huge arrays of commands.
- A file is created in the root while the script is running: ignored or handled next run, no crash.

## 12. Out of scope for this version

No recursion into subfolders, no sorting by date subfolders, no deletion or archiving of old files, no duplicate detection by content, no scheduling, no GUI, no config file. Keep the category table and the settings (skip list, stamp types, minimum age) as clearly labelled variables at the top of the .ps1 so I can edit them.

## 13. Test plan (build and run this)

Create a throwaway test folder with copies of the scripts and these fixtures, then run preview, real run, second run and undo, and show me the screen output and the log after each:

1. One file of every category extension, in upper and lower case.
2. `2610 already.pdf` (already stamped) and `2024 Budget.pdf` (looks like a stamp, is not one).
3. A PDF, a DOCX and an MD file with CreationTime set to a past month, to prove the prefix uses the created date. Set it with PowerShell on the fixture. The MD file must end up as `MarkItdown\YYMM name.md`.
3a. MD stamp checks: `2610 already.md` (already stamped, must move unchanged), `2024 Notes.md` (looks like a stamp, is not one, so it is stamped), and an upper-case `README2.MD` (extension matched case-insensitively and stamped). Also a loose `notes.md` whose stamped name already exists in a pre-existing `MarkItdown` folder (must be LEFT, no second attempt).
4. A hidden file and a file with the system attribute.
5. A subfolder with a PDF inside, plus a pre-existing `Documents` folder containing `2610 report.pdf`, and a loose `report.pdf` created in that month (clash case), plus loose clashing `video.mp4` and `script.py` (must be left).
6. A file named with Tamil text, an emoji, brackets, `%`, `!` and `&`.
7. A file opened exclusively by another process (locked).
8. `fake.crdownload`, `desktop.ini`, an extension-less file, and `archive.tar.gz`.

Pass criteria: preview changes nothing and its listing matches the real run; real run matches the rules in sections 4 to 8; every moved file is in the log with correct From and To; locked file shows FAILED and the rest completes; second run moves 0; undo restores every MOVED file of the last run to its original path and name and nothing else.

## 14. How I want you to work

1. Read this fully, then reply with a short build plan and any questions. Wait for my approval.
2. Build in small steps: launcher and settings block first, then classification, then naming and clash rules, then logging, then undo.
3. Test each step with the fixtures above and show me the evidence, not just a claim that it works.
4. If a rule here is unclear or conflicts with another, ask me. Do not silently choose.
5. Keep the code short and commented in plain English so I can review it.
6. When finished, give me a one-page summary of what each file does and any rule you had to interpret.

## 15. Changes after Trial 2 (these override earlier sections)

- Tool lives in a `.sort` folder placed inside the folder to sort; the root is the parent of `.sort`. Log: `.sort\history\sort-log.csv` (replaces `SortLog`). Log paths are relative to the root; undo also accepts older full-path logs.
- Prefix is `YYMMDD` (setting `$StampFormat`, `yyMM` still possible). A name that already starts with a valid YYMM or YYMMDD stamp is not stamped again.
- Prefix date = the earlier of created and modified (`$StampDateSource`: Earliest, Created or Modified), because copying a file resets its created date.
- Duplicates: if the destination already holds a file with the same size and modified time (within 2 seconds), under the same name or the same name with a date prefix, the loose file is left in place, for every file type. Logged as LEFT with the note `identical file already in destination: <name>`. Nothing is moved, renamed or deleted.
- Screen output: LEFT and FAILED lines show the intended destination and the reason, and the run ends with a "Needs your attention" list.

## 16. Changes after Trial 3 (these override earlier sections)

- Log rows are written one by one as each file is handled; no row is lost if the run is interrupted. Columns are now `Run,Action,From,To,Note,Size,Modified`. An older-format log is renamed and a new one started. The same LEFT/FAILED row is not logged again on later runs.
- Undo: a run stays open until each of its moved files is restored or can never be restored (file gone, or changed since the sort). Skips because the original path is occupied are retried; `-GiveUp` stops retrying them.
- A loose file named like a category folder is not moved and is reported FAILED, so results no longer depend on file order.
- Duplicate check indexes by file size (3000 files in one folder: fast). Optional `$HashCheck` compares SHA-256 across names and dates.
- Files modified in the last 120 seconds are skipped (`$MinAgeSeconds`). A future date is replaced by today when stamping.
- Preview reports a file that is in use as FAILED.
- Optional settings: `$TidyNames`, `$IncludeSubfolders`.

## 17. Duplicates folder (overrides the "left in place" duplicate rule in section 15)

- An identical file (same size, plus same name or date-prefixed name and same modified time within 2 seconds; optional SHA-256 check) found in the file's category folder or in `_copy` is moved into `_copy` under its own name, never deleted. Log Note: `duplicate of <folder>\<name>`. Undo reverses it like any move.
- If that name is already taken in `_copy`, one retry with the date prefix; if still taken the file is left and listed under "Needs your attention".
- Setting `$DuplicatesFolder` (default `_copy`; empty = leave duplicates in place).

## 17. Duplicates folder (overrides the "left in place" duplicate rule in section 15)

- An identical file (same size, plus same name or date-prefixed name and same modified time within 2 seconds; optional SHA-256 check) found in the file's category folder or in `_copy` is moved into `_copy` under its own name, never deleted. Log Note: `duplicate of <folder>\<name>`. Undo reverses it like any move.
- If that name is already taken in `_copy`, one retry with the date prefix; if still taken the file is left and listed under "Needs your attention".
- Setting `$DuplicatesFolder` (default `_copy`; empty = leave duplicates in place).

## 18. Changes after the stress tests (these override earlier sections)

- Leading/trailing spaces in a name are quoted in the log (names such as `  report .pdf` now restore exactly).
- Undo treats a file as done when an identical file (same size and modified time) already sits at its original path; a different file there is skipped and retried (`-GiveUp` to stop retrying).
- Only one real sort or undo can run on a folder at a time (named mutex per folder); a preview is always allowed.
- Log writes retry when another program holds the file; if still locked at the end the run finishes and warns how many rows were not written.
- `Code` folder extended to about 75 extensions (all common programming, markup and config-as-code formats).
