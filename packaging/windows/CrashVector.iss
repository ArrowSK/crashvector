; CrashVector Windows installer
; Built by GitHub Actions after the Godot export is produced.

#define MyAppName "CrashVector"
#ifndef AppVersion
  #define AppVersion "0.1.0-beta.1"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\dist\windows"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist\package"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "CrashVector-0.1.0-beta.1-Windows-x64-Setup"
#endif

[Setup]
AppId={{C4BB4017-4B1F-4BDA-91F8-E38E31187E7D}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppVerName={#MyAppName} {#AppVersion}
AppPublisher=ArrowSK
AppPublisherURL=https://github.com/ArrowSK/crashvector
AppSupportURL=https://github.com/ArrowSK/crashvector/issues
AppUpdatesURL=https://github.com/ArrowSK/crashvector/releases
DefaultDirName={autopf}\CrashVector
DefaultGroupName=CrashVector
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=..\..\assets\branding\crashvector-icon.ico
UninstallDisplayIcon={app}\CrashVector.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
ChangesAssociations=no
DisableWelcomePage=no
VersionInfoVersion=0.1.0.1
VersionInfoCompany=ArrowSK
VersionInfoDescription=CrashVector installer
VersionInfoProductName=CrashVector
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\CrashVector.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\CrashVector"; Filename: "{app}\CrashVector.exe"
Name: "{group}\Uninstall CrashVector"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\CrashVector.exe"; Description: "Launch CrashVector"; Flags: nowait postinstall skipifsilent
