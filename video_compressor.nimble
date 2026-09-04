# Package
version       = "0.1.0"
author        = "shaaaaaQ"
description   = "A native video compressor built with Nim, uirelays, and local FFmpeg"
license       = "MIT-0"
srcDir        = "src"
binDir        = "bin"
bin           = @["video_compressor"]

# Dependencies
requires "nim >= 2.0.0"
requires "uirelays == 0.8.0"

task buildRelease, "Build the native release executable":
  when defined(windows):
    exec "nim c --threads:on --mm:orc --app:gui -d:release --nimcache:nimcache -o:bin/video-compressor src/video_compressor.nim"
  else:
    exec "nim c --threads:on --mm:orc -d:release --nimcache:nimcache -o:bin/video-compressor src/video_compressor.nim"

task buildInstaller, "Build the Windows installer with Inno Setup":
  when defined(windows):
    exec "iscc installer/video-compressor.iss"
  else:
    echo "This task is available only on Windows."

task registerExplorer, "Add video-compressor to the Windows Explorer context menu":
  when defined(windows):
    exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/register-explorer.ps1"
  else:
    echo "This task is available only on Windows."

task unregisterExplorer, "Remove video-compressor from the Windows Explorer context menu":
  when defined(windows):
    exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/register-explorer.ps1 -Uninstall"
  else:
    echo "This task is available only on Windows."
