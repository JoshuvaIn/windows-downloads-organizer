[← Back to README](../README.md)

# Testing

## The headline

**20,000 files in one folder: sorted, sorted again and fully undone, with no file lost or overwritten.** On a normal laptop that took a few minutes. A further 5,000-file test mixed in 70 file types, Tamil, Japanese and emoji names, copies, name clashes and old-format names, and every file's content was checked before and after (11,939 files).

## What else was tried

| Test | Result |
|---|---|
| Sort interrupted half-way (window closed, process killed) | Everything moved so far was already in the log. Undo and a second run finished the job. |
| Two sorts started at the same time | The second is refused with a message. |
| A file open in another program | That file is reported as `FAILED`; the rest carry on. |
| A folder you are not allowed to write to | The files for it are reported as `FAILED`. |
| The log open in Excel during a sort | The tool waits and retries. Files are still sorted. |
| Awkward names (spaces, commas, `%`, `!`, `&`, brackets, very long) | Moved and restored with exactly the same name. |
| Folders with spaces and symbols in their path | Worked from the `.bat` files. |

Testing also found six bugs, all fixed. The log lost leading spaces in names, undo could retry forever, an interrupted run lost its log, two runs at once could crash one, an open log could crash a run, and a file dated in the future was treated as a download in progress.

## Known limits

- **Windows 11 only.** Tested with Windows PowerShell 5.1, the version that comes with Windows 11. Other Windows versions, PowerShell 7, network drives and OneDrive-synced folders were not tested and are not supported.
- Destinations longer than 259 characters fail safely rather than moving.
- Dates before the year 2000 use two digits (`991231`), so they sort after recent ones.
- If you put a different file at a file's old name after a sort, undo skips that file.
- Some antivirus products dislike `.bat` files that start PowerShell. If yours blocks it, allow the `.sort` folder.

## Try it yourself

```
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Smoke-Test.ps1
```

It builds a throwaway folder in your temporary files, runs 25 checks through preview, sort, copies, a clash, a locked file and undo, then deletes the folder. It never touches your own files.

---

[← Back to README](../README.md)
