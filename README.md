# PW Docs

A standalone document editor for Windows, forked from ONLYOFFICE Desktop
Editors v9.4.0 and stripped to the Document (Word) editor only.

## Repository layout

This repo is the **umbrella**: it tracks the fork itself, not a copy of the
upstream source. The eight ONLYOFFICE repositories are cloned alongside it and
are gitignored.

| Path | Contents |
|---|---|
| [`MANIFEST.md`](MANIFEST.md) | exact upstream repos, branches and commits — reproduces the fork |
| [`docs/`](docs) | per-phase analysis; start with the dependency map |
| [`branding/`](branding) | icon generator and generated `.ico` assets |
| `build_tools/` … `web-apps/` | upstream clones (gitignored) |

## What was removed, and what deliberately was not

Decided from `sdkjs/configs/word.json` — the build manifest that lists every
file compiled into the document editor bundle. Full reasoning in
[`docs/phase-2-dependency-map.md`](docs/phase-2-dependency-map.md).

**Removed** — `sdkjs/slide`, `sdkjs/visio`, and the `spreadsheeteditor`,
`presentationeditor`, `pdfeditor` and `visioeditor` web UI apps (~575 MB).
`word.json` references none of them.

**Kept, against the original plan:**

- **`sdkjs/cell/`** — `word.json` pulls in 9 files from it, including
  `Workbook.js`, `WorkbookElems.js`, `SheetMemory.js` and `parserFormula.js`.
  That is the mini-spreadsheet that backs **chart data editing** in a
  document. `word/` also calls `AscCommonExcel.c_sPerDay`, defined in
  `cell/utils/utils.js`, for date field formatting. Deleting `cell/` breaks
  both.
- **`sdkjs/pdf/`** — `word.json` pulls in **57** files. As of v9.4.0 the PDF
  engine is compiled into the document bundle rather than being a separate
  editor, and it is what backs PDF export.

Chart data editing was traced end to end to confirm the spreadsheet *UI* app
was safe to delete: the chart grid opens through
`Common.Views.ExternalDiagramEditor`, which renders into a `div` in-process
and returns via `asc_editChartDrawingObject()`. It never navigates to the
spreadsheet app.

## Coexistence with other PW editors

PW Docs uses its own mutex, window class, `AppUserModelID`, URL protocol and
registry root, set identically in `win-linux/src/defines.h` and
`package/inno/defines.iss`. Leaving any of these at the upstream value makes
Windows treat PW Docs and an installed ONLYOFFICE or PW Office suite as the
same application, which breaks single-instance activation, taskbar grouping
and settings isolation.

## Build

Requires Visual Studio (MSVC), Qt 5.15.2 `msvc2019_64`, Python 3, Node.js and
roughly 30 GB of free disk.

```powershell
cd D:\pw-docs\build_tools
python configure.py --module desktop --platform win_64 --update 0 --qt-dir C:\Qt\5.15.2
python make.py
```

`--update 0` matters: without it `configure.py` re-clones the upstream repos
and discards the PW Docs changes.

## Licence

Derivative work of ONLYOFFICE Desktop Editors, licensed under the **GNU AGPL
v3**. The original Ascensio System SIA copyright is retained in the version
resources as AGPL section 5 requires. Distributing the binary obliges you to
make this source available to its users.
