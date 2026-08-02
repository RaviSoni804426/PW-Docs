# Phase 2 — Codebase Analysis & Dependency Map

ONLYOFFICE `release/v9.4.0`. This document decides what Phase 3 may delete.

## The authoritative source: `sdkjs/configs/*.json`

Each editor has a build manifest listing every JS file that goes into its
bundle. Grepping for cross-module strings is guesswork; these manifests are
what the build actually reads. `sdkjs/build/build.py` consumes them.

File counts per module, per editor bundle:

| config | `word` | `common` | `pdf` | `cell` | `slide` | `visio` | `vendor` |
|---|---|---|---|---|---|---|---|
| **`word.json`** (PW Docs) | 236 | 136 | **57** | **9** | 0 | 0 | 6 |
| `cell.json` | 197 | 135 | 0 | 64 | 1 | 0 | 6 |
| `slide.json` | 199 | 134 | 0 | 10 | 37 | 0 | 11 |
| `visio.json` | 192 | 122 | 0 | 9 | 12 | 12 | 5 |

Two things fall out of this immediately:

1. `word/` is the **base layer for every editor** — the spreadsheet bundle
   pulls in 197 files from `word/`, the presentation bundle 199. It is not
   "the document editor" so much as the core text/layout engine that the
   others build on. Deleting it was never on the table; this confirms why.
2. The document bundle pulls in **`cell/` and `pdf/`**, and pulls in
   **nothing** from `slide/` or `visio/`.

## `word/` → `cell/` — CHART DEPENDENCY CONFIRMED, KEEP

`word.json` includes these 9 files from `cell/`:

```
cell/model/Workbook.js              cell/model/WorkbookElems.js
cell/model/Serialize.js             cell/model/CellInfo.js
cell/model/HeaderFooter.js          cell/model/SheetMemory.js
cell/model/FormulaObjects/parserFormula.js
cell/utils/utils.js                 cell/view/HandlerList.js
```

This is exactly the mini-spreadsheet engine that backs chart data editing —
`Workbook`/`WorkbookElems`/`SheetMemory` are the grid model, `parserFormula`
is the formula parser, `Serialize` handles the embedded XLSX part that a
DOCX chart stores its data in.

Independently confirmed at runtime level: `word/` references
`AscCommonExcel.c_sPerDay` in 6 files (date/time field formatting), and
`c_sPerDay` is defined in `cell/utils/utils.js:56`. Deleting `cell/` would
break date fields *and* chart data editing.

> **Verdict: `cell/` is KEPT.**

Note that the `AscCommonExcel` namespace is *created* by
`word/Editor/Document.js:29140` and written to by `word/Drawing/Graphics.js`
— so the coupling is bidirectional, not a one-way import. There is no clean
seam to cut here.

## `word/` → `pdf/` — FUSED, KEEP

`word.json` includes **57 files** from `pdf/` — the entire PDF engine:
viewer, annotations, forms, drawings, history, search, thumbnails.

In v9.4.0 the PDF module is no longer a separate editor that happens to sit
in the same repo; it is compiled into the document editor bundle. This is
what backs PDF open/view and PDF export from within Docs.

> **Verdict: `pdf/` is KEPT** (the sdkjs module). The separate
> `web-apps/apps/pdfeditor` **UI app** is a different thing and is deleted.

## `word/` → `slide/`, `visio/` — CLEAN, DELETE

Zero entries in `word.json`. Safe to remove.

## `web-apps/apps/documenteditor` → other editor UIs — CLEAN

7 hits for `spreadsheeteditor|presentationeditor|pdfeditor|visioeditor`,
**all of them in localized help HTML** (`resources/help/{en,ru,de,fr,pt,tr,
sr-Latn}/UsageInstructions/InsertTables.htm` — prose mentioning the other
editors). Zero references in JS, JSON, or templates.

> **Verdict: all four non-document UI apps are safe to delete.**

## Phase 3 delete list

| Path | Size | Action |
|---|---|---|
| `sdkjs/slide/` | 21.7 MB | DELETE |
| `sdkjs/visio/` | 0.7 MB | DELETE |
| `sdkjs/cell/` | 10.1 MB | **KEEP** — chart data engine |
| `sdkjs/pdf/` | 40.0 MB | **KEEP** — fused into word bundle |
| `sdkjs/word/`, `common/`, `vendor/` | — | **KEEP** |
| `web-apps/apps/spreadsheeteditor/` | 444.9 MB | DELETE |
| `web-apps/apps/presentationeditor/` | 66.8 MB | DELETE |
| `web-apps/apps/pdfeditor/` | 34.6 MB | DELETE |
| `web-apps/apps/visioeditor/` | 6.1 MB | DELETE |
| `web-apps/apps/documenteditor/`, `common/`, `api/` | — | **KEEP** |

Reclaimed: ~575 MB, almost all of it in `web-apps`.

`sdkjs/cell/` and `sdkjs/pdf/` stay whole rather than being trimmed to just
the 9 + 57 manifest files. Trimming would save ~45 MB but risks transitive
breakage for no meaningful gain — the desktop build only ships the compiled
bundle, not the source tree, so unused source costs nothing in the installer.

## Build system findings (`build_tools/configure.py`)

`--module` accepts `core desktop builder server mobile` — there is **no
per-editor module flag**. Editor selection is not a build_tools concern; it
happens in `sdkjs/configs/` and `web-apps`.

Relevant flags for later phases:

| Flag | Use |
|---|---|
| `--branding=PATH` | **official branding hook** |
| `--branding-name=NAME` | product name |
| `--branding-url=URL` | product URL |
| `--platform=win_64` | target |
| `--module=desktop` | build desktop app |
| `--no-apps` | skip Qt apps (not wanted) |
| `--vs-version`, `--vs-path` | MSVC location |

**This changes the Phase 4 plan.** The original plan did a blind
find-and-replace of `ONLYOFFICE` → `PW Docs` across every source file. That
is destructive and unnecessary: it would rewrite AGPL license headers, break
`Asc.c_oAscEditorId`-style internal identifiers, corrupt URLs pointing at
`onlyoffice.com` API endpoints, and mangle `.ts`/`.json` keys that other code
looks up by name. The supported branding mechanism should be used instead,
with targeted edits only where it doesn't reach.

## Installer findings

`desktop-apps/package/inno/` already contains a working Inno Setup project:
`common.iss`, `defines.iss`, `_code.iss`, `_messages.iss`, `help.iss`.

Phase 6 should parameterise these rather than author a new `.iss` from
scratch — the existing scripts already handle file associations, the update
daemon, per-user vs per-machine install, and 20+ UI languages.

## Windows resource / icon locations

```
desktop-apps/win-linux/version.rc
desktop-apps/win-linux/extras/projicons/version.rc
desktop-apps/win-linux/extras/projicons/res/langs/translation.rc
desktop-apps/win-linux/extras/update-daemon/res/version.rc
desktop-apps/win-linux/extras/projicons/res/icons/*.ico   (per file-type icons)
```

`res/icons/` holds one `.ico` per associated file type (`docx.ico`,
`xlsx.ico`, `pptx.ico`, `odt.ico`, …) plus `desktopeditors.ico` as the app
icon. Phase 4 replaces the app icon and the document-family icons, and the
non-document ones simply stop being registered by the installer.
