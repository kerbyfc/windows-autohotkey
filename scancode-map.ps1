$ErrorActionPreference = 'Stop'
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
$dir = Join-Path $env:USERPROFILE '.config\autohotkey'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$backup = Join-Path $dir ('scancode-map-before-install-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.reg')
reg export 'HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout' $backup /y | Out-Null
# CapsLock больше не переводится в Esc драйвером: dual-role (Esc одиночным,
# Ctrl в аккорде) разбирает AHK. Остальные перестановки — как были.
$bytes = [byte[]](
    0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
    0x04,0x00,0x00,0x00,
    0x1D,0x00,0x38,0x00,
    0x38,0x00,0x5B,0xE0,
    0x5B,0xE0,0x1D,0xE0,
    0x00,0x00,0x00,0x00
)
Set-ItemProperty -Path $key -Name 'Scancode Map' -Value $bytes -Type Binary
$new = (Get-ItemProperty -Path $key -Name 'Scancode Map').'Scancode Map'
'backup=' + $backup
'new=' + (($new | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
