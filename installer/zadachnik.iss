; Установщик Задачника для Windows (Inno Setup 6). Собирается в GitHub Actions.
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6F2C9B1E-4A7D-4C3B-9E21-5B8D0A7C3F14}
AppName=Задачник
AppVersion={#AppVersion}
AppPublisher=Задачник
DefaultDirName={autopf}\Zadachnik
DefaultGroupName=Задачник
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\zadachnik.exe
UninstallDisplayName=Задачник
OutputDir=..\dist
OutputBaseFilename=Zadachnik-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Задачник"; Filename: "{app}\zadachnik.exe"
Name: "{autodesktop}\Задачник"; Filename: "{app}\zadachnik.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\zadachnik.exe"; Description: "{cm:LaunchProgram,Задачник}"; Flags: nowait postinstall skipifsilent
