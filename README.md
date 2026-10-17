# Downloads Organizer for Windows 11

**Tidy a messy Downloads folder with one double-click. See what will happen first, undo it any time, and nothing is ever deleted.**

![A Downloads folder before and after sorting](docs/images/before-after.svg)

## What it does

It looks at the loose files in a folder and puts each one into a folder for its type: `Images`, `Videos`, `Audio`, `Documents`, `Code`, `Archives`, `Installers` and a few more. PDFs and Word files also get the date at the front of their name, like `260908 Tax return.pdf`.

- **Nothing to install.** It uses PowerShell, which is already part of Windows 11.
- **Preview first.** One button shows exactly what would move. Nothing changes.
- **Undo.** One button puts everything back.
- **Safe.** It never deletes a file and never overwrites one. Copies of files you already have are set aside in a `_copy` folder for you to look at.
- **Use it again next month.** It only deals with what has piled up since.

## How to use it

1. Copy the **`.sort`** folder into the folder you want to tidy (usually `Downloads`).
2. Double-click **`Sort-Downloads-Preview.bat`** to see what would happen.
3. Happy? Double-click **`Sort-Downloads.bat`**.
4. Changed your mind? Double-click **`Undo-Last-Sort.bat`**.

![The preview window](docs/images/preview-output.svg)

Windows may show a blue "Windows protected your PC" box the first time. Choose **More info**, then **Run anyway**. The [quick start](docs/QUICK-START.md) explains this and everything else on one page.

## Is it safe?

- It only touches loose files in the folder you put it in. Anything hidden, any unfinished download, and anything changed in the last two minutes is left alone.
- Every move is written to a log as it happens, so even a sort that gets interrupted can be undone.
- It was stress-tested with **20,000 files in one folder**, with files locked by other programs, with two copies started at once and with the log open in Excel. **No file was lost or overwritten.** The [short test summary](docs/TESTING.md) has the details.

## Good to know

- **Windows 11 only.** It was built and tested on Windows 11, using the PowerShell that comes with it. Other versions of Windows are not tested or supported, and it does not run on Mac or Linux.
- It sorts by file type, using the file's extension. It does not read inside files.
- The sorting rules are a list at the top of one text file, so you can change them in Notepad.
- It runs when you start it. It does not watch the folder or run on a schedule.

## More

- [Quick start](docs/QUICK-START.md): one page, with what to do if something looks different.
- [How it works](docs/HOW-IT-WORKS.md): every rule in plain English.
- [How it compares](docs/COMPARISON.md): other tools, and when to pick them instead.

## Licence

GNU General Public Licence, version 3. In short: you may use, change and share it, and if you share a changed version it must stay open source under the same licence. The full text is in [LICENSE](LICENSE).
