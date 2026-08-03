# Phase 7 — Test Plan

Ordered by risk. The first section covers things **this fork specifically put
at risk**; a generic "does Word stuff work" pass is section 4 and matters less
because none of it was touched.

## 1. The strip decisions — highest risk

These verify the Phase 2 analysis was right. If any fail, the fix is to
restore the module from git (see [MANIFEST.md](../MANIFEST.md)) rather than to
patch around it.

| # | Test | Why it's here | Fails if |
|---|---|---|---|
| 1.1 | Insert a chart, then double-click it and **edit its data grid** | The whole `cell/` keep-or-delete decision. `word.json` pulls 9 files from `cell/`; the grid renders in-process through `Common.Views.ExternalDiagramEditor` | grid doesn't open, or opens empty, or edits don't write back to the chart |
| 1.2 | Insert a chart → change values → confirm the chart redraws | Verifies `asc_editChartDrawingObject()` round-trip, not just that a grid appeared | chart doesn't update |
| 1.3 | Save a doc with a chart as `.docx`, reopen, edit chart data again | Chart data lives in an embedded XLSX part handled by `cell/model/Serialize.js` | data lost or grid empty on reopen |
| 1.4 | Insert a **date field** and a `DATE` content control | `word/` calls `AscCommonExcel.c_sPerDay` from `cell/utils/utils.js` in 6 places | wrong date, or a JS console error |
| 1.5 | **Export to PDF** | `word.json` pulls 57 files from `pdf/`; this is why `pdf/` was kept | export fails or produces a broken file |
| 1.6 | Insert SmartArt and an equation | Both live in `common/`, which was kept but sits next to deleted trees | missing UI or render failure |

## 2. Text/locale — the ICU stub question

`icudt74.dll` builds from `stubdata.cpp` with `/D STUBDATA_BUILD` and is ~3 KB.
The log shows this is ICU's own solution doing it with ONLYOFFICE's unmodified
module, so it should match every upstream build — but that was reasoned from
build output, not observed at runtime. These tests settle it.

| # | Test | Fails if |
|---|---|---|
| 2.1 | Type a long **Devanagari** (Hindi) paragraph; confirm it wraps at sensible points | text doesn't wrap, wraps mid-cluster, or renders as boxes |
| 2.2 | Same for **Arabic** (RTL) — confirm direction and shaping | letters unjoined or left-to-right |
| 2.3 | Long **Chinese/Japanese** line — CJK breaks between characters | overflows without breaking |
| 2.4 | Sort a table column with mixed-case and accented text | ordering ignores locale collation |
| 2.5 | Spell check in English **and** a second language | dictionaries don't load |

## 3. Identity and coexistence

Phase 4 moved the mutex, window class, `AppUserModelID`, URL protocol and
registry root off the upstream values. This section proves that worked, and it
only means something with another ONLYOFFICE-derived app installed.

| # | Test | Fails if |
|---|---|---|
| 3.1 | Install PW Docs **alongside** PW Office / ONLYOFFICE; launch both together | one activates the other's window instead of opening (shared mutex) |
| 3.2 | Confirm they occupy **separate taskbar groups** | shared `AppUserModelID` |
| 3.3 | Change a setting in PW Docs, confirm the other app is unaffected | shared `REG_GROUP_KEY` |
| 3.4 | Uninstall one; confirm the other still launches and keeps its settings | shared uninstall key or registry root |
| 3.5 | Both appear separately in Add/Remove Programs with correct names/icons | shared `REG_UNINST_KEY` |

## 4. Document-only surface

| # | Test | Expected |
|---|---|---|
| 4.1 | Start screen | **only** a DOCX creation card |
| 4.2 | Templates panel | **only** the Documents category — no Spreadsheets / Presentations / PDFs tabs |
| 4.3 | Templates search box | cannot surface a non-document template (the loader filters to `word` before adding) |
| 4.4 | File → Open dialog | document formats only; no `.xlsx` / `.pptx` / `.vsdx` / `.pdf` filters |
| 4.5 | Open an `.xlsx` via drag-drop or command line | graceful refusal, not a crash or blank window |
| 4.6 | Window title / About dialog | "PW Docs" |
| 4.7 | Taskbar and Explorer icons | blue PW Docs document icon |
| 4.8 | Installer wizard | PW Docs artwork, both light and dark Windows themes |

## 5. Core editing regression

Untouched by the fork, so a smoke pass is enough — but a failure here means
something in the strip had wider reach than the analysis found.

Text formatting (bold/italic/font/size/colour/highlight) · heading styles ·
alignment, spacing, indents · bulleted and numbered multilevel lists · find &
replace · tables (insert, merge, borders) · images with text wrap · shapes and
text boxes · hyperlinks · comments · track changes accept/reject · headers,
footers, page numbers · columns, page and section breaks · table of contents
from headings · footnotes and endnotes · word count · print preview.

## 6. File round-trips

Save and reopen each: `.docx` · `.doc` · `.odt` · `.rtf` · `.txt` · `.dotx`.
Then open a **complex Word document produced elsewhere** — nested tables,
floating images, custom styles, a TOC — and confirm fidelity. This is the test
most likely to expose a missing `common/` asset.

## 7. File associations

`.docx` is the only extension the installer registers (`_code.iss`). Confirm
double-click opens PW Docs, the icon is correct in Explorer, and that
uninstalling removes the association cleanly.

> `.doc`, `.odt`, `.rtf`, `.txt` and `.dotx` are **openable but not
> registered**. Registering `.txt` in particular would hijack every text file
> on the machine. If they should be associated too, that is a deliberate
> addition to the `args` array in `_code.iss`, not an oversight.
