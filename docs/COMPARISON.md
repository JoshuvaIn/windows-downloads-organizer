# How it compares

Other tools tidy files too, and some are better at it in their own way. This page is an honest look at where Downloads Organizer fits. The details come from each project's own page (read 18 October 2026), and where a page does not say, this page says "not stated" rather than guessing. Check the links before relying on a detail.

| | Downloads Organizer | [organize](https://github.com/tfeldmann/organize) | [Foldr](https://github.com/foldrhq/Foldr) | [Mouzi](https://github.com/hsr88/mouzi) | [DropIt](https://sourceforge.net/projects/dropit/) | Windows Storage Sense |
|---|---|---|---|---|---|---|
| What it is | Fixed-rule sorter for one folder | Rule engine, command line | Command-line organiser | Tray app that sorts Downloads | Drag-and-drop rule organiser | Built-in clean-up |
| Works on | Windows 11 | Windows, Mac, Linux | Cross-platform | Windows | Windows | Windows |
| Needs installing | No | Python and pip | Not stated | Yes (tray app) | Installer or portable | No |
| Rules to write first | No | Yes (YAML file) | Not stated | Not stated | Yes | No |
| Preview | Yes | Yes | Yes | Not stated | Not stated | No |
| Undo | Yes | Not stated | Yes | Not stated | Not stated | No |
| Deletes files | Never | Can | Not stated | Not stated | Can | Yes, that is its job |
| Watches a folder | No | Not stated | Not stated | Yes (automatic) | Yes | Runs on a schedule |

**organize** is the most capable open-source choice: your own rules, many actions, three operating systems. It needs Python and a rules file, and its page does not mention undo. Pick it if you want precise custom rules.

**Foldr** and **Mouzi** are newer projects found through GitHub's topic pages. Foldr is described as a cross-platform command-line organiser with preview and undo. Mouzi is described as a privacy-first tray app that sorts Downloads automatically, and it is the most-starred project on GitHub's `downloads-organizer` topic. I did not run either, so I cannot say how they handle name clashes, interrupted runs or copies.

**DropIt** is a Windows drop-zone organiser with 21 actions and profiles. Its SourceForge page shows a last update in 2018.

**Windows Storage Sense** is different: for Downloads it *deletes* files you have not opened for a number of days you choose, and only if you turn it on. It does not sort.

## Where this one is different

- **No install and no setup.** Copy a folder, double-click. No Python, no app, no rules to write.
- **Preview and undo are the main feature.** Every move is logged as it happens, so even an interrupted run can be reversed.
- **Copies are kept, not deleted.** An identical copy of a sorted file goes to `_copy` for you to review. A different file with the same name is never replaced.
- **The date at the front of a name survives copying.** It uses the earlier of the created and modified dates.
- **Everything lives in one folder** (`.sort`). No registry entries, services or scheduled tasks to remove afterwards.

## Where the others are better

- You want your own rules, such as "invoices go here": use **organize** or **DropIt**.
- You want a folder watched all the time: use **Mouzi** or **DropIt**.
- You use a Mac or Linux: use **organize** or **Foldr**.
- You want a proper window with buttons: use **DropIt** or a tray app.

## About the pictures in this project

They were made for this project. I did not copy images from other projects, because those belong to their authors. The terminal pictures come from real output of the tool on a demo folder.
