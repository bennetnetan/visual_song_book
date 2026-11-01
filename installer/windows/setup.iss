; ---------------------------------------------------------------------------
; Visual Song Book — Windows installer script (Inno Setup 6)
;
; Produces a normal wizard installer — Welcome -> License -> All users / just
; me -> Install location -> Start Menu -> Installing -> Finished with a
; "Launch now" checkbox — rather than a silent extract, so app testers see
; exactly what is installed and where it goes.
;
; Build from CI:
;   ISCC.exe /DMyAppVersion=2.5.0 ^
;       /DMyAppSourceDir=<repo>\build\windows\x64\runner\Release ^
;       installer\windows\setup.iss
;
; Or locally with Inno Setup installed:
;   ISCC.exe installer\windows\setup.iss
;
; Every path below is derived from SourcePath (the script's own folder) so the
; result does not depend on which directory ISCC is launched from.
; ---------------------------------------------------------------------------

#define MyAppName "Visual Song Book"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define ScriptDir AddBackslash(SourcePath)
; installer/windows/ -> repository root is two levels up
#define RepoRoot AddBackslash(ScriptDir + "..\..")

; The Flutter Windows release bundle; CI always passes an absolute path.
#ifndef MyAppSourceDir
  #define MyAppSourceDir RepoRoot + "build\windows\x64\runner\Release"
#endif

#define MyAppPublisher "Visual Song Book"
#define MyAppURL "https://github.com/bennetnetan/visual_song_book"
#define MyAppExeName "visual_song_book.exe"
; Stable AppId — changing it breaks upgrade-in-place for existing installs.
; The braces are doubled because Inno Setup reads an unescaped { in a
; directive as the start of a constant reference, not a literal brace.
#define MyAppId "{{693D5F43-A69E-4A6F-BC2E-FB39D4BB0358}}"

; Show the MIT license as a wizard page when the file is present, so a compile
; outside a full checkout still succeeds.
#ifexist RepoRoot + "LICENSE"
  #define MyAppLicensePath RepoRoot + "LICENSE"
#endif

; Bundle the VC++ 2015-2022 redistributable (x64) so the runtime check below
; works offline. CI downloads it into redist\ before compiling.
#ifexist ScriptDir + "redist\vc_redist.x64.exe"
  #define BundleVCRedist
#endif

[Setup]
; AppId must stay constant across releases so reinstalling upgrades the
; existing install instead of leaving a second copy behind.
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} {#MyAppVersion}

; One elevation prompt up front. This is the right default for a shared church
; machine and is required for the VC++ runtime step below; the dialog override
; still lets an admin choose a per-user install instead.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Keep the "Select Destination Location" page: choosing where the app is
; installed is one of the steps a tester should see, not have taken for them.
DisableDirPage=no

; Installers land in dist/ at the repository root.
OutputDir={#RepoRoot}dist
OutputBaseFilename=visual_song_book-{#MyAppVersion}-setup
SourceDir={#MyAppSourceDir}

#ifdef MyAppLicensePath
LicenseFile={#MyAppLicensePath}
#endif

Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Flutter Windows release bundle: visual_song_book.exe,
; flutter_windows.dll, the data\ asset folder and every plugin DLL.
; recursesubdirs matters — the exe alone will not start.
Source: "*"; DestDir: "{app}"; Excludes: "*.pdb,*.lib,*.exp"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Stage the redistributable to a temp folder; the [Code] section runs it only
; when the runtime is actually missing, and Setup removes the temp copy itself.
; uninsneveruninstall cannot be combined with {tmp} or deleteafterinstall,
; and is meaningless here: Setup always reaps temp files.
;
; The source is an absolute path because a relative Source resolves against
; SourceDir, which points at the Flutter bundle — not at this script's folder.
#ifdef BundleVCRedist
Source: "{#ScriptDir}redist\vc_redist.x64.exe"; DestDir: "{tmp}"; \
    Flags: deleteafterinstall
#endif

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
; "Launch Visual Song Book now" checkbox on the final wizard page.
Filename: "{app}\{#MyAppExeName}"; \
    Description: "{cm:LaunchProgram,{#MyAppName}}"; \
    Flags: nowait postinstall skipifsilent

[Code]
{ ------------------------------------------------------------------------- }
{ Visual C++ runtime prerequisite                                            }
{                                                                            }
{ Flutter's Windows bundle does not ship msvcp140.dll / vcruntime140.dll.    }
{ Without the VC++ 2015-2022 redistributable the app exits immediately with   }
{ a missing-DLL error, which would look like a broken installer to a tester. }
{ We detect that from the registry and install the bundled redistributable   }
{ silently before the app's own files are placed. If anything goes wrong we   }
{ log it and continue — a failed prerequisite must never leave the app        }
{ half-installed.                                                            }
{ ------------------------------------------------------------------------- }

function IsVCRuntimeInstalled(): Boolean;
var
  // LongWord, not Integer: RegQueryDWORDValue declares its out parameter as an
  // unsigned DWord, and passing a signed Integer fails with "Type mismatch".
  Installed: LongWord;
begin
  Result := False;

  // Exit takes no argument in Inno Setup's Pascal Script — set Result first.
  if RegQueryDWORDValue(HKLM,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Installed', Installed) then
    if Installed = 1 then
    begin
      Result := True;
      Exit;
    end;

  if RegQueryDWORDValue(HKCU,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Installed', Installed) then
    if Installed = 1 then
    begin
      Result := True;
      Exit;
    end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  RedistPath: String;
begin
  Result := '';
  NeedsRestart := False;

  if IsVCRuntimeInstalled() then
  begin
    Log('VC++ runtime already present; skipping prerequisite.');
    Exit;
  end;

  RedistPath := ExpandConstant('{tmp}\vc_redist.x64.exe');

  if not FileExists(RedistPath) then
  begin
    Log('VC++ redistributable was not bundled; skipping prerequisite.');
    Exit;
  end;

  { /install /quiet /norestart: no UI, never reboots under the tester. }
  if Exec(RedistPath, '/install /quiet /norestart', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode) then
  begin
    Log(Format(
      'VC++ redistributable installed, result code %d.', [ResultCode]));
    { 3010 == installed, but a restart is required. }
    if ResultCode = 3010 then
      NeedsRestart := True;
  end
  else
    Log('VC++ redistributable failed to run; it may need to be installed '
        + 'manually before the app will start.');
end;
