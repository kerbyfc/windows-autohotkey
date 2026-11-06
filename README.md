# windows-autohotkey

Настройка клавиатуры Windows на AutoHotkey v2: язык по одиночному Ctrl, Ctrl-аккорды
на русской раскладке, CapsLock как Esc/Ctrl, перестановка модификаторов.

## Что делает

- перестановка модификаторов — две карты, вариант выбирается по железу
  (см. «Карта клавиш» ниже);
- одиночное нажатие клавиши у пробела (ставшей Ctrl) переключает язык;
- Ctrl-аккорд на русской раскладке временно уходит в английский и возвращает русский
  после отпускания;
- `CapsLock`: одиночное нажатие — `Esc`, удержание в аккорде — `Ctrl` (с тем же
  временным английским); LED CapsLock не загорается.
- `Ctrl+Shift+[` / `Ctrl+Shift+]` — предыдущая/следующая вкладка (`Ctrl+Shift+Tab` /
  `Ctrl+Tab`), как `Cmd+Shift+[` / `]` на маке; работает и на русской раскладке.

## Установка

Нужны Windows и права администратора: установщик пишет `Scancode Map` в
`HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout`.

1. Склонируй репозиторий.
2. Запусти `install.ps1` от администратора (правой кнопкой → «Запустить с правами
   администратора») или:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

   Скрипт сам перезапустится с UAC, если прав нет (окно остаётся открытым, чтобы
   было видно ошибки).

Установщик:

- ставит или обновляет AutoHotkey v2 через winget (`AutoHotkey\v2\AutoHotkey64.exe`);
- копирует `keyboard.ahk` и `scancode-map.ps1` в `%USERPROFILE%\.config\autohotkey`;
- останавливает старый AutoHotkey и убирает прежний ярлык `Ctrl-Tap Language.lnk`;
- создаёт ярлык `Keyboard.lnk` в Startup;
- применяет карту клавиш (бэкап прежней — `scancode-map-before-install-<дата>.reg`);
- запускает `keyboard.ahk`.

**Перезагрузись** — `Scancode Map` применяется только при старте системы. До
перезагрузки модификаторы работают по прежней карте.

## Карта клавиш

Вариантов два, потому что у PC- и Mac-клавиатуры разный порядок клавиш слева от
пробела. На Mac под Boot Camp драйвер Apple отдаёт `Option` как `Alt`, а `Cmd` как
`Win`, то есть PC-карта сделала бы `Ctrl` из `Option`, а `Cmd` превратила бы в `Alt`.

| Физическая клавиша | PC-карта | Mac-карта |
|---|---|---|
| `Left Alt` / `Option` | `Left Ctrl` | `Alt` (как есть) |
| `Left Win` / левый `Cmd` | `Alt` | **`Left Ctrl`** |
| `Left Ctrl` | `Ctrl` (как есть) | `Ctrl` (как есть) |
| `Right Ctrl` | `Left Win` | на маке такой клавиши нет |
| `Right Win` / правый `Cmd` | — | `Win` (как есть) |

В Mac-карте поэтому всего одна перестановка: `Win` остаётся на правом `Cmd`,
`Option` драйвер Apple и так отдаёт как `Alt`, физический `Ctrl` не трогаем. Побочное
следствие — физический `Ctrl` тоже переключает язык одиночным нажатием, потому что
для AHK он тот же `LControl`, что и левый `Cmd`.

`CapsLock` в карте нет ни в одном варианте: dual-role `Esc`/`Ctrl` разбирает AHK.

Вариант выбирается по производителю из `Win32_ComputerSystem`: Apple → Mac-карта.
На любом другом железе **карта не трогается вообще** — PC-вариант применяется только
по явному флагу. Оба флага есть и у `install.ps1`, и у `scancode-map.ps1`:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Mac
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Pc
```

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
