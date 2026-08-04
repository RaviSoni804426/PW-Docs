# PW Docs — Upstream Source Manifest

PW Docs is a fork of the ONLYOFFICE Desktop Editors, stripped down to the
Document (Word) editor only.

The eight upstream repositories are **not vendored** into this repo. This
manifest records the exact upstream state so any machine can reproduce the
identical fork. All modifications live in [`patches/`](patches/).

## Upstream repositories

Cloned from `https://github.com/ONLYOFFICE/<repo>.git` on 2026-08-02.

| Repo | Branch / Tag | HEAD commit | Size |
|---|---|---|---|
| `build_tools` | `release/v9.4.0` | `cf4cac0` | 15.6 MB |
| `core` | `release/v9.4.0` | `55e5f973` | 617 MB |
| `desktop-apps` | `release/v9.4.0` | `3ad4e29` | 324 MB |
| `desktop-sdk` | `release/v9.4.0` | `c84d59c` | 64.8 MB |
| `dictionaries` | `master` | `d3223bb` | 238 MB |
| `document-templates` | `master` | `71430c9` | 4.4 MB |
| `sdkjs` | `release/v9.4.0` | `d8e4124` | 126 MB |
| `web-apps` | `release/v9.4.0` | `1993a6d8` | 720 MB |

Total: **2.06 GB**

`dictionaries` and `document-templates` have no `release/v9.4.0` branch — they
are pure data repos and are not version-coupled to the build.

## Reproducing the fork

```powershell
$plan = [ordered]@{
  "build_tools"        = "release/v9.4.0"
  "desktop-apps"       = "release/v9.4.0"
  "sdkjs"              = "release/v9.4.0"
  "web-apps"           = "release/v9.4.0"
  "core"               = "release/v9.4.0"
  "desktop-sdk"        = "release/v9.4.0"
  "dictionaries"       = "master"
  "document-templates" = "master"
}
foreach ($r in $plan.Keys) {
  git clone --depth 1 --single-branch --branch $plan[$r] `
    "https://github.com/ONLYOFFICE/$r.git" "D:\pw-docs\$r"
  git -C "D:\pw-docs\$r" checkout -b pw-docs
}
```

All PW Docs work happens on the `pw-docs` branch of each repo. The pristine
upstream branch is left intact locally, so any deleted or modified path can be
restored without a re-clone:

```powershell
git -C D:\pw-docs\sdkjs checkout release/v9.4.0 -- slide/
```

This is why no `_backup/` directories are used — git is the backup, and it is
both authoritative and free of disk cost.

## Licensing

ONLYOFFICE is licensed under AGPL v3. PW Docs is a derivative work and carries
the same license. Source must be made available to users of the distributed
binary.

## Local modifications

Source changes live in `patches/`, since the upstream repos above are fetched
rather than vendored. Apply them after cloning.

| Patch | What it changes |
|---|---|
| `projicons-appusermodelid.patch` | Gives PW Docs its own `APP_USER_MODEL_ID`. `ProjIcons.pro` declares it a second time, separately from `defines.h`, and was left on the upstream value — so Windows grouped PW Docs' taskbar button with any other app carrying it. |
