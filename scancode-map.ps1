param(
    [switch]$Mac,
    [switch]$Pc
)
$ErrorActionPreference = 'Stop'

if ($Mac -and $Pc) { throw 'Выбери одно: -Mac или -Pc' }

# Карта нужна Mac-клавиатуре: у MacBook под Boot Camp порядок клавиш слева от
# пробела другой — драйвер Apple отдаёт Option как Alt, а Cmd как Win. На обычном
# PC по умолчанию не трогаем ничего: PC-вариант есть, но только по явному -Pc.
if ($Mac) {
    $isMac = $true
} elseif ($Pc) {
    $isMac = $false
} else {
    $vendor = (Get-CimInstance Win32_ComputerSystem).Manufacturer
    if ($vendor -notlike 'Apple*') {
        'layout=skip (железо не Apple: ' + $vendor + ') — Scancode Map не тронута'
        return
    }
    $isMac = $true
}

# Пары байт в записи: сначала новый скан-код, потом исходный (little-endian).
# CapsLock в карте нет: dual-role (Esc одиночным, Ctrl в аккорде) разбирает AHK.
if ($isMac) {
    # Хватает одной записи: левый Cmd -> Ctrl. Option драйвер Apple уже отдаёт как
    # Alt, физический Ctrl и так Ctrl, а Win остаётся на правом Cmd.
    $bytes = [byte[]](
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x02,0x00,0x00,0x00,
        0x1D,0x00,0x5B,0xE0,
        0x00,0x00,0x00,0x00
    )
} else {
    # PC-клавиатура: LAlt -> Ctrl, LWin -> Alt, RCtrl -> Win.
    $bytes = [byte[]](
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
        0x04,0x00,0x00,0x00,
        0x1D,0x00,0x38,0x00,
        0x38,0x00,0x5B,0xE0,
        0x5B,0xE0,0x1D,0xE0,
        0x00,0x00,0x00,0x00
    )
}

$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
$dir = Join-Path $env:USERPROFILE '.config\autohotkey'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$backup = Join-Path $dir ('scancode-map-before-install-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.reg')
reg export 'HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout' $backup /y | Out-Null
Set-ItemProperty -Path $key -Name 'Scancode Map' -Value $bytes -Type Binary
$new = (Get-ItemProperty -Path $key -Name 'Scancode Map').'Scancode Map'
if ($isMac) { 'layout=mac (Cmd -> Ctrl)' } else { 'layout=pc (LAlt -> Ctrl)' }
'backup=' + $backup
'new=' + (($new | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
