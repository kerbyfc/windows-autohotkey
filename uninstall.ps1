$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    exit
}

Get-Process AutoHotkeyU64 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

$startup = [Environment]::GetFolderPath('Startup')
foreach ($name in @('Keyboard.lnk', 'Ctrl-Tap Language.lnk')) {
    Remove-Item -LiteralPath (Join-Path $startup $name) -ErrorAction SilentlyContinue
}

$dir = Join-Path $env:USERPROFILE '.config\autohotkey'
$backup = Get-ChildItem -LiteralPath $dir -Filter 'scancode-map-before-install-*.reg' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($backup) {
    reg import $backup.FullName | Out-Null
    Write-Host "карта клавиш возвращена: $($backup.FullName)"
} else {
    Write-Host 'бэкап карты не найден — Scancode Map оставлена как есть'
}

foreach ($name in @('keyboard.ahk', 'scancode-map.ps1')) {
    Remove-Item -LiteralPath (Join-Path $dir $name) -ErrorAction SilentlyContinue
}

Write-Host 'Удалено. Перезагрузи компьютер, чтобы вернуть прежнюю карту клавиш.'
