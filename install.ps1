$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    exit
}

$root = $PSScriptRoot

function Find-Ahk {
    foreach ($base in @($env:ProgramFiles, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        $exe = Join-Path $base 'AutoHotkey\v2\AutoHotkey64.exe'
        if (Test-Path -LiteralPath $exe) { return $exe }
    }
    return $null
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
    $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $candidate) { $winget = $candidate }
}

# Скрипт под AutoHotkey v2: ставим или обновляем до последней версии.
if ($winget) {
    & $winget install --id AutoHotkey.AutoHotkey -e --scope machine --accept-source-agreements --accept-package-agreements
    if (-not (Find-Ahk)) {
        & $winget upgrade --id AutoHotkey.AutoHotkey -e --accept-source-agreements --accept-package-agreements
    }
}
$ahk = Find-Ahk
if (-not $ahk) {
    throw 'AutoHotkey v2 не найден (AutoHotkey\v2\AutoHotkey64.exe): поставь AutoHotkey v2 и повтори'
}

$dir = Join-Path $env:USERPROFILE '.config\autohotkey'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'keyboard.ahk') -Destination $dir -Force
Copy-Item -LiteralPath (Join-Path $root 'scancode-map.ps1') -Destination $dir -Force

Get-Process AutoHotkey, AutoHotkey64, AutoHotkey32, AutoHotkeyU64, AutoHotkeyU32 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

$startup = [Environment]::GetFolderPath('Startup')
foreach ($name in @('Ctrl-Tap Language.lnk', 'Keyboard.lnk')) {
    Remove-Item -LiteralPath (Join-Path $startup $name) -ErrorAction SilentlyContinue
}

$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut((Join-Path $startup 'Keyboard.lnk'))
$link.TargetPath = $ahk
$link.Arguments = '"' + (Join-Path $dir 'keyboard.ahk') + '"'
$link.WorkingDirectory = $dir
$link.WindowStyle = 1
$link.Save()

& (Join-Path $dir 'scancode-map.ps1')
Start-Process -FilePath $ahk -ArgumentList ('"' + (Join-Path $dir 'keyboard.ahk') + '"')

Write-Host 'Установлено: keyboard.ahk и карта клавиш.'
Write-Host 'Перезагрузи компьютер — Scancode Map применяется только при старте.'
