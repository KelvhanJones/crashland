; Planecrash Survival — Windows installer
; Rebuild:
;   flutter build windows --release
;   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\planecrash_survival.iss

#define MyAppName "Planecrash Survival"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Planecrash Survival"
#define MyAppExeName "crashland.exe"
#define MyAppSource "..\build\windows\x64\runner\Release"

[Setup]
AppId={{E7C4A91B-3F52-4D8E-A6B1-9C2E5F8D4A70}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright="Copyright (C) 2026"
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=PlanecrashSurvival-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#MyAppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.zip"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Planecrash Survival"; Flags: nowait postinstall skipifsilent
