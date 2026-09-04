#define MyAppName "video-compressor"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "shaaaaaQ"
#define MyAppExeName "video-compressor.exe"

[Setup]
AppId={{83baf6c9-fe72-4738-a905-2c1b89b4eec3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/shaaaaaQ/video-compressor
AppSupportURL=https://github.com/shaaaaaQ/video-compressor/issues
AppUpdatesURL=https://github.com/shaaaaaQ/video-compressor/releases
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=video-compressor-setup-{#MyAppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
RestartApplications=no
LicenseFile=..\LICENSE

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "explorer"; Description: "動画の右クリックメニューに「video-compressor で圧縮」を追加する"; GroupDescription: "エクスプローラー連携:"; Flags: unchecked

[Files]
Source: "..\bin\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Registry]
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#MyAppName}"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\VideoCompressor"; ValueType: string; ValueName: "MUIVerb"; ValueData: "video-compressor で圧縮"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\VideoCompressor"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\VideoCompressor\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\VideoCompressor"; ValueType: string; ValueName: "MUIVerb"; ValueData: "video-compressor で圧縮"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\VideoCompressor"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\VideoCompressor\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\VideoCompressor"; ValueType: string; ValueName: "MUIVerb"; ValueData: "video-compressor で圧縮"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\VideoCompressor"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\VideoCompressor\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\VideoCompressor"; ValueType: string; ValueName: "MUIVerb"; ValueData: "video-compressor で圧縮"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\VideoCompressor"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\VideoCompressor\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\VideoCompressor"; ValueType: string; ValueName: "MUIVerb"; ValueData: "video-compressor で圧縮"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\VideoCompressor"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\VideoCompressor\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\VideoCompressor"; ValueType: string; ValueName: "MUIVerb"; ValueData: "video-compressor で圧縮"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\VideoCompressor"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\VideoCompressor\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wmv\shell\VideoCompressor"; ValueType: string; ValueName: "MUIVerb"; ValueData: "video-compressor で圧縮"; Tasks: explorer; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wmv\shell\VideoCompressor"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName}"; Tasks: explorer
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wmv\shell\VideoCompressor\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: explorer

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{#MyAppName} を起動する"; Flags: nowait postinstall skipifsilent
