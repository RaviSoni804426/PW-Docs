; PW Docs - Inno Setup installer script
; Build with:  ISCC.exe /DSourceDir="<path to the built app>" pwdocs_setup.iss
;
; The repository had no installer script; the shipped installer was produced
; outside version control, so it could not be rebuilt when the application
; changed. This packages a deployed application directory.

#define AppName        "PW Docs"
#define AppVersion     "1.0.0.0"
; PWDocs.exe is the projicons shim - it sets the taskbar identity, carries the
; file-type icons and starts editors.exe. Shortcuts must point here: launching
; editors.exe directly fails, because it delay-loads kernel.dll out of
; converter\ and that only resolves once the shim has set the process up.
#define AppExeName     "PWDocs.exe"
#ifndef SourceDir
  #define SourceDir    "C:\Program Files\PWDocs"
#endif
; Relative to this script, so it keeps working wherever the repo is checked out.
#define BrandingIcon   SourcePath + "branding\icons\PWDocs.ico"

[Setup]
; Matches the AppId already in the registry (HKLM\...\Uninstall\PW Docs_is1),
; so this upgrades the existing install rather than landing beside it.
AppId=PW Docs
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Physics Wallah
; Must stay "PWDocs" with no space: cupdatemanager compares the install
; folder's basename against REG_APP_NAME and disables updates on mismatch.
DefaultDirName={autopf}\PWDocs
DefaultGroupName={#AppName}
OutputDir={#SourcePath}installer-output
OutputBaseFilename=PW-Docs-{#AppVersion}-x64
SetupIconFile={#BrandingIcon}
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; The payload is mostly already-compressed data (CEF, fonts, dictionaries), so
; ultra64 costs a great deal of time for very little size gain.
Compression=lzma2/max
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=2
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=admin
DisableProgramGroupPage=yes
DisableDirPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"
Name: "assoc_docx"; Description: "Open .docx files with {#AppName}"; GroupDescription: "File associations:"
Name: "assoc_doc";  Description: "Open .doc files with {#AppName}";  GroupDescription: "File associations:"
Name: "assoc_odt";  Description: "Open .odt files with {#AppName}";  GroupDescription: "File associations:"

[Files]
; Keep rollback copies of patched binaries out of the payload. Do NOT add a
; bare "*.bak" - ONLYOFFICE ships real product files with that extension
; (dictionaries/hyph_sl_SI.dic.bak), and excluding those silently drops
; product data.
; unins000.* is Inno's own uninstaller, regenerated on every install; when the
; payload comes from an installed copy those files are sitting there, and
; shipping them installs a stale uninstaller over the fresh one.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.bak-*,*.bak2,*.bak3,unins000.*"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}";            Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}";  Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";      Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; --- Application registration -------------------------------------------
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#AppExeName}"; \
    ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName}"; Flags: uninsdeletekey

; --- ProgIDs -------------------------------------------------------------
; Document formats only. PW Docs is a document-only application.
Root: HKCR; Subkey: "PWDocs.docx"; ValueType: string; ValueName: ""; ValueData: "Word Document"; Flags: uninsdeletekey; Tasks: assoc_docx
Root: HKCR; Subkey: "PWDocs.docx\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"; Tasks: assoc_docx
Root: HKCR; Subkey: "PWDocs.docx\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: assoc_docx
Root: HKCR; Subkey: ".docx"; ValueType: string; ValueName: ""; ValueData: "PWDocs.docx"; Flags: uninsdeletevalue; Tasks: assoc_docx

Root: HKCR; Subkey: "PWDocs.doc"; ValueType: string; ValueName: ""; ValueData: "Word 97-2003 Document"; Flags: uninsdeletekey; Tasks: assoc_doc
Root: HKCR; Subkey: "PWDocs.doc\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"; Tasks: assoc_doc
Root: HKCR; Subkey: "PWDocs.doc\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: assoc_doc
Root: HKCR; Subkey: ".doc"; ValueType: string; ValueName: ""; ValueData: "PWDocs.doc"; Flags: uninsdeletevalue; Tasks: assoc_doc

Root: HKCR; Subkey: "PWDocs.odt"; ValueType: string; ValueName: ""; ValueData: "OpenDocument Text"; Flags: uninsdeletekey; Tasks: assoc_odt
Root: HKCR; Subkey: "PWDocs.odt\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"; Tasks: assoc_odt
Root: HKCR; Subkey: "PWDocs.odt\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: assoc_odt
Root: HKCR; Subkey: ".odt"; ValueType: string; ValueName: ""; ValueData: "PWDocs.odt"; Flags: uninsdeletevalue; Tasks: assoc_odt

; --- "Open with" entries (always registered, even without taking over the
;     default) so the formats show up in Explorer's Open-with list. --------
Root: HKCR; Subkey: "Applications\{#AppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Flags: uninsdeletekey
Root: HKCR; Subkey: ".docx\OpenWithProgids"; ValueType: string; ValueName: "PWDocs.docx"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCR; Subkey: ".doc\OpenWithProgids";  ValueType: string; ValueName: "PWDocs.doc";  ValueData: ""; Flags: uninsdeletevalue
Root: HKCR; Subkey: ".odt\OpenWithProgids";  ValueType: string; ValueName: "PWDocs.odt";  ValueData: ""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: postinstall nowait skipifsilent
