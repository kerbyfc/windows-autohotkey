# windows-autohotkey

Настройка клавиатуры Windows на AutoHotkey v1: язык по одиночному Ctrl, Ctrl-аккорды
на русской раскладке, CapsLock как Esc/Ctrl, перестановка модификаторов.

## Что делает

- физический `Left Alt` работает как `Left Ctrl`, `Left Win` — как `Left Alt`,
  `Right Ctrl` — как `Left Win`;
- одиночное нажатие `Left Alt` (ставшего Ctrl) переключает язык;
- Ctrl-аккорд на русской раскладке временно уходит в английский и возвращает русский
  после отпускания;
- `CapsLock`: одиночное нажатие — `Esc`, удержание в аккорде — `Ctrl` (с тем же
  временным английским); LED CapsLock не загорается.

## Установка

Нужны Windows и права администратора: установщик пишет `Scancode Map` в
`HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout`.

1. Склонируй репозиторий.
2. Запусти `install.ps1` от администратора (правой кнопкой → «Запустить с правами
   администратора») или:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

   Скрипт сам перезапустится с UAC, если прав нет.

Установщик:

- ставит AutoHotkey через winget, если `AutoHotkeyU64.exe` нет;
- копирует `keyboard.ahk` и `scancode-map.ps1` в `%USERPROFILE%\.config\autohotkey`;
- останавливает старый AutoHotkey и убирает прежний ярлык `Ctrl-Tap Language.lnk`;
- создаёт ярлык `Keyboard.lnk` в Startup;
- применяет карту клавиш (бэкап прежней — `scancode-map-before-install-<дата>.reg`);
- запускает `keyboard.ahk`.

**Перезагрузись** — `Scancode Map` применяется при старте системы. До перезагрузки
CapsLock ещё работает по старой карте.

## Удаление

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

От администратора: останавливает AutoHotkey, убирает ярлык, возвращает карту из
последнего `scancode-map-before-install-*.reg` и удаляет файлы из
`%USERPROFILE%\.config\autohotkey`. Перезагрузись.

Старые `ctrl-tap-language.ahk`, `set-keyboard-map.ps1` и бэкапы
`scancode-map-before-*.reg` после новой установки не используются; их можно удалить
вручную, если не нужен откат.

## macOS

Не поддерживается: это Windows-репозиторий. На маке модификаторы и CapsLock
настраиваются Karabiner-Elements, а клавиши WezTerm — в `wezterm-config`.
