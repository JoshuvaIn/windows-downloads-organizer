# Changelog

All notable changes to Downloads Organizer. Dates are day/month/year.

## Unreleased

- README now opens with a wide picture, lists what you get, shows the folder structure, and ends with a short stress-test summary.
- Pictures redrawn wider and with fewer files, so they read well on a web page; the flowchart has larger text.
- New banner and social preview picture, badges, a feature grid and quick links at the top of the README.
- Issue forms for problems and ideas, and a short contributing guide.

## 1.0.0 - 18/10/2026 (first release)

- Sorts the loose files of a folder into `Images`, `Videos`, `Audio`, `Documents`, `MarkItdown`, `Archives`, `Installers`, `Code` and `Other`.
- Preview launcher that changes nothing.
- Undo launcher, driven by a log written one row at a time.
- Date prefix (`YYMMDD`, earliest of created and modified date) on PDF, Word, PowerPoint and Markdown files.
- Identical copies of sorted files are moved to `_copy`. Nothing is ever deleted or overwritten.
- Files that are hidden, system, unfinished downloads or changed in the last two minutes are left alone.
- One sort or undo at a time on a folder; the log is retried if another program has it open.
- Tested on Windows 11 with Windows PowerShell 5.1, up to 20,000 files in one folder.
