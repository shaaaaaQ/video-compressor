param(
    [switch] $Uninstall
)

$ErrorActionPreference = 'Stop'

$executable = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\bin\video-compressor.exe')
)
$applicationKey = 'HKCU:\Software\Classes\Applications\video-compressor.exe'
$extensions = @('.mp4', '.mov', '.mkv', '.webm', '.avi', '.m4v', '.wmv')

if ($Uninstall) {
    Remove-Item -LiteralPath $applicationKey -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($extension in $extensions) {
        $verbKey = "HKCU:\Software\Classes\SystemFileAssociations\$extension\shell\VideoCompressor"
        Remove-Item -LiteralPath $verbKey -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host 'Explorer integration was removed.'
    exit 0
}

if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Executable not found: $executable`nRun 'nimble buildRelease' first."
}

$command = '"{0}" "%1"' -f $executable

New-Item -Path $applicationKey -Force | Out-Null
New-ItemProperty -Path $applicationKey -Name 'FriendlyAppName' -Value 'video-compressor' -PropertyType String -Force | Out-Null
New-Item -Path "$applicationKey\SupportedTypes" -Force | Out-Null
New-Item -Path "$applicationKey\shell\open\command" -Force | Out-Null
Set-Item -Path "$applicationKey\shell\open\command" -Value $command

foreach ($extension in $extensions) {
    New-ItemProperty -Path "$applicationKey\SupportedTypes" -Name $extension -Value '' -PropertyType String -Force | Out-Null

    $verbKey = "HKCU:\Software\Classes\SystemFileAssociations\$extension\shell\VideoCompressor"
    New-Item -Path "$verbKey\command" -Force | Out-Null
    New-ItemProperty -Path $verbKey -Name 'MUIVerb' -Value 'video-compressor で圧縮' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $verbKey -Name 'Icon' -Value $executable -PropertyType String -Force | Out-Null
    Set-Item -Path "$verbKey\command" -Value $command
}

Write-Host 'Explorer integration was registered.'
Write-Host 'On Windows 11, the command may appear under "Show more options".'
