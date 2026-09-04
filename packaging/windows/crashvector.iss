; CrashVector Windows installer. generated_version.iss is generated from project.godot.
#include "generated_version.iss"

#define MyAppName "CrashVector"
#define MyAppPublisher "ArrowSK"
#define MyAppExeName "CrashVector.exe"

[Setup]
AppId={{F0C38B9E-5F8B-4D4C-B9E1-C1A2F9D4A90F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppNumericVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=CrashVector Setup
VersionInfoProductName={#MyAppName}
DefaultDirName={autopf}\CrashVector
DefaultGroupName=CrashVector
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=..\..\dist
OutputBaseFilename=CrashVector-{#MyAppVersion}-Windows-x64-Setup
SetupIconFile=..\..\build\icons\CrashVector.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
MinVersion=10.0.17763

[Files]
Source: "..\..\build\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\CrashVector"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch CrashVector"; Flags: nowait postinstall skipifsilent
