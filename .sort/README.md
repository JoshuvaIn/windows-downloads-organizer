# .sort - Downloads Organizer

Copy this `.sort` folder into the folder you want to tidy. The folder that contains it is the one that gets sorted.

| Double-click | What it does |
|---|---|
| `Sort-Downloads-Preview.bat` | Shows what would happen. Changes nothing. |
| `Sort-Downloads.bat` | Sorts the files. |
| `Undo-Last-Sort.bat` | Puts the files from the latest sort back. |

The log of every move is kept in `history\sort-log.csv`. Keep it if you want undo to reach back over older sorts.

Settings are at the top of `Sort-Downloads.ps1`, in plain English. Open it in Notepad.

Full guide: see the README and the `docs` folder of the project this came from.