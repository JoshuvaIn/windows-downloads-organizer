# Downloads Organizer for Windows 11

**Tidy a messy Downloads folder with one double-click. See what will happen first, undo it any time, and nothing is ever deleted.**

![A Downloads folder before and after sorting](docs/images/before-after.svg)

## What you get

| You get | What it is |
|---|---|
| `Sort-Downloads-Preview.bat` | Double-click to see exactly what would move. Nothing changes. |
| `Sort-Downloads.bat` | Double-click to sort the folder. |
| `Undo-Last-Sort.bat` | Double-click to put the last sort back. |
| `Sort-Downloads.ps1` and `Undo-Last-Sort.ps1` | The plain-text scripts behind those buttons. Open them in Notepad to read them, or to change which file types go where. |
| `history\sort-log.csv` | A record of every move, made the first time you sort. Undo uses it. |
| Guides in `docs\` | A one-page quick start, how every rule works, a comparison with other tools, and the test notes. |
| `tests\Smoke-Test.ps1` | A one-minute check you can run on a throwaway folder to see it work. |
| Release ZIP | Just the `.sort` folder, for anyone who would rather not use git. |

## How the folders look

Copy the `.sort` folder into the folder you want to tidy, usually `Downloads`:

```
Downloads\
    .sort\                          <- the tool (copy this folder)
        Sort-Downloads-Preview.bat      look first, changes nothing
        Sort-Downloads.bat              sort the files
        Undo-Last-Sort.bat              put them back
        Sort-Downloads.ps1              the sorting rules and logic
        Undo-Last-Sort.ps1              the undo logic
    holiday.mp4                     <- your loose files, still where they were
    invoice.pdf
    photo.jpg
```

After the first sort:

```
Downloads\
    .sort\                          <- the tool, stays where it is
        history\                        the log, made on the first sort
    Videos\       holiday.mp4
    Documents\    260908 invoice.pdf    (PDF and Word files get a date at the front)
    Images\       photo.jpg
    _copy\        (only appears if you download the same file twice)
```

## How to use it

1. Copy the **`.sort`** folder into the folder you want to tidy.
2. Double-click **`Sort-Downloads-Preview.bat`** to see what would happen.
3. Happy? Double-click **`Sort-Downloads.bat`**.
4. Changed your mind? Double-click **`Undo-Last-Sort.bat`**.

![The preview window](docs/images/preview-output.svg)

Windows may show a blue "Windows protected your PC" box the first time. Choose **More info**, then **Run anyway**. The [quick start](docs/QUICK-START.md) explains this and everything else on one page.

## Why you might like it

- **Nothing to install.** It uses PowerShell, which is already part of Windows 11.
- **Preview first, undo any time.** Every move is logged as it happens, so even an interrupted sort can be undone.
- **Safe.** It never deletes a file and never overwrites one. Copies of files you already have are set aside in `_copy` for you to look at.
- **Fine to repeat.** Run it again next month and it only deals with what has piled up since.

## Good to know

- **Windows 11 only.** It was built and tested on Windows 11, using the PowerShell that comes with it. Other versions of Windows are not tested or supported, and it does not run on Mac or Linux.
- It sorts by file type, using the file's extension. It does not read inside files.
- It leaves alone anything hidden, any unfinished download, and anything changed in the last two minutes.
- It runs when you start it. It does not watch the folder or run on a schedule.

## More

- [Quick start](docs/QUICK-START.md): one page, with what to do if something looks different.
- [How it works](docs/HOW-IT-WORKS.md): every rule in plain English.
- [How it compares](docs/COMPARISON.md): other tools, and when to pick them instead.

## Stress test, in short

**20,000 files in one folder: sorted, sorted again and fully undone, with no file lost or overwritten.** It was also tried with files locked by other programs, two copies started at once, the log open in Excel, and sorts killed half-way. Details are in [the test notes](docs/TESTING.md).

## Licence

GNU General Public Licence, version 3. In short: you may use, change and share it, and if you share a changed version it must stay open source under the same licence. The full text is in [LICENSE](LICENSE).
