; Одиночный Ctrl переключает язык; Ctrl-аккорд на русской раскладке
; временно уходит в английский и после аккорда возвращается обратно.
; CapsLock: одиночное нажатие — Esc, удержание в аккорде — Ctrl с тем же
; временным английским. Перестановка модификаторов — в ScanCode Map.
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

SetCapsLockState "AlwaysOff"
OnExit CapsRelease
SetTimer CapsWatchdog, 500

global ctrlUsed := false
global ctrlActive := false
global ctrlDownTime := 0
global wasRussian := false
global lastToggle := 0
global lastEnglishHkl := 0
global capsActive := false
global capsUsed := false
global capsWasRussian := false
global capsDownTime := 0
global ctrlHwnd := 0
global ctrlTid := 0
global altTabActive := false

~LControl::
{
    global
    if (ctrlActive)
        return
    ctrlActive := true
    ctrlUsed := false
    ctrlDownTime := A_TickCount
    wasRussian := false
    ctrlHwnd := 0
    ctrlTid := 0

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if !tid
        return
    ctrlHwnd := hwnd
    ctrlTid := tid
    current := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    lang := current & 0xFFFF
    if (lang = 0x0419) {
        wasRussian := true
        SwitchToEnglish(hwnd, tid)
    } else if (lang = 0x0409) {
        lastEnglishHkl := current
    }
}

~LControl Up::
{
    global
    ctrlActive := false

    ; Ctrl+Tab переключал окна: отпускаем Alt — переключатель выбирает окно.
    ; Русский возвращаем исходному окну, а не новому активному.
    if (altTabActive) {
        altTabActive := false
        Send "{Blind}{LAlt Up}"
        if (wasRussian && ctrlHwnd && ctrlTid)
            SwitchToRussian(ctrlHwnd, ctrlTid)
        ctrlUsed := false
        wasRussian := false
        return
    }

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    tid := 0
    if hwnd
        tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")

    if (ctrlUsed) {
        if (wasRussian && hwnd && tid)
            SwitchToRussian(hwnd, tid)
        ctrlUsed := false
        wasRussian := false
        return
    }

    ; Аккорд: нажата другая клавиша или ещё один модификатор.
    if (A_PriorKey != "LControl" && A_PriorKey != "Control") {
        if (wasRussian && hwnd && tid)
            SwitchToRussian(hwnd, tid)
        wasRussian := false
        return
    }
    if (GetKeyState("Shift", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P")) {
        if (wasRussian && hwnd && tid)
            SwitchToRussian(hwnd, tid)
        wasRussian := false
        return
    }

    ; Долгое удержание — не одиночное нажатие.
    if (A_TickCount - ctrlDownTime > 600) {
        if (wasRussian && hwnd && tid)
            SwitchToRussian(hwnd, tid)
        wasRussian := false
        return
    }

    ; Защита от автоповтора/дребезга.
    if (A_TickCount - lastToggle < 300) {
        wasRussian := false
        return
    }
    lastToggle := A_TickCount

    if (wasRussian) {
        ; На нажатии уже ушли в английский — это и есть переключение.
    } else if (hwnd && tid) {
        SwitchToRussian(hwnd, tid)
    }
    wasRussian := false
}

; CapsLock: Ctrl, пока зажат; Esc — один раз при отпускании и только если за
; время удержания не нажали ничего другого. Время удержания не ограничено,
; автоповтор игнорируется. Драйвер больше не переводит CapsLock в Esc
; (scancode-map.ps1), иначе AHK не увидит клавишу.
; Ловим по скан-коду SC03A: в Colemak эта клавиша — Backspace, а не CapsLock, и
; после переключения на английский отпускание иначе не поймать (Ctrl залипал).
*SC03A::
{
    global
    if (capsActive)
        return
    capsActive := true
    capsUsed := false
    capsWasRussian := false
    capsDownTime := A_TickCount

    ; Ctrl — сразу, чтобы первая клавиша аккорда уже шла с модификатором.
    ; SendLevel 0: хоткеи ~LControl его не видят, в A_PriorKey он не попадает,
    ; а модификатором для ^-хоткеев (Ctrl+Shift+[) остаётся.
    Send "{Blind}{LControl Down}"

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if !tid
        return
    current := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    if ((current & 0xFFFF) = 0x0419) {
        capsWasRussian := true
        SwitchToEnglish(hwnd, tid)
    }
}

*SC03A Up::
{
    global
    ; Ctrl отпускаем всегда, даже если состояние уже сбросил сторож.
    Send "{Blind}{LControl Up}"
    if (!capsActive)
        return
    capsActive := false

    ; Свой Send на SendLevel 0 в историю клавиш не попадает, поэтому A_PriorKey —
    ; последняя физическая клавиша. Сама эта клавиша называется CapsLock или
    ; Backspace (Colemak); настоящий Backspace ловит хоткей ниже.
    if (A_PriorKey != "" && A_PriorKey != "CapsLock" && A_PriorKey != "Backspace")
        capsUsed := true

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    tid := 0
    if hwnd
        tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if (capsWasRussian && hwnd && tid)
        SwitchToRussian(hwnd, tid)

    if (!capsUsed)
        Send "{Esc}"

    capsUsed := false
    capsWasRussian := false
}

; Настоящий Backspace (SC00E) при зажатом CapsLock — аккорд Ctrl+Backspace.
#HotIf capsActive
~*SC00E::
{
    global capsUsed
    capsUsed := true
}
#HotIf

; Как Cmd+Shift+[ / ] на маке: Ctrl+Shift+[ — предыдущая вкладка, Ctrl+Shift+] —
; следующая. Скан-коды, чтобы работало и на русской раскладке (х/ъ).
^+SC01A::Send "^+{Tab}"
^+SC01B::Send "^{Tab}"

; Как Cmd+Tab на маке: Ctrl+Tab / Ctrl+Shift+Tab — переключатель окон (Alt+Tab).
; Только настоящий левый Ctrl (физический Alt), не CapsLock: Caps+Tab остаётся
; переключением вкладок. Ctrl логически отпускаем, иначе Ctrl+Alt+Tab откроет
; «залипающий» переключатель; Alt держим до отпускания физического Ctrl.
#HotIf !capsActive
<^Tab::
<^+Tab::
{
    global altTabActive
    altTabActive := true
    Send "{Blind}{LControl Up}{LAlt Down}{Tab}"
}
#HotIf altTabActive
*Tab::Send "{Blind}{Tab}"

; Alt+Tab (физический Win) — вкладки, как Ctrl+Shift+] / [. Отключено, пока
; открыт переключатель окон: там Alt наш синтетический.
#HotIf !altTabActive
<!Tab::Send "^{Tab}"
<!+Tab::Send "^+{Tab}"
#HotIf

; Мышь с зажатым Ctrl — не одиночное нажатие.
~*LButton::
~*RButton::
~*MButton::
~*WheelUp::
~*WheelDown::
{
    global
    if GetKeyState("Ctrl", "P")
        ctrlUsed := true
    if (capsActive)
        capsUsed := true
}

; Страховка от потерянного отпускания (UAC, блокировка экрана): CapsLock
; физически отпущен, а мы всё ещё держим Ctrl. Esc при этом не шлём.
CapsWatchdog() {
    global
    if (capsActive && !GetKeyState("SC03A", "P")) {
        capsActive := false
        Send "{Blind}{LControl Up}"
        capsUsed := false
        capsWasRussian := false
    }
}

CapsRelease(*) {
    global
    if (capsActive) {
        capsActive := false
        Send "{Blind}{LControl Up}"
    }
}

KeyboardLayouts() {
    count := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0)
    layouts := []
    if (count <= 0)
        return layouts
    buf := Buffer(count * A_PtrSize, 0)
    DllCall("GetKeyboardLayoutList", "Int", count, "Ptr", buf)
    Loop count
        layouts.Push(NumGet(buf, (A_Index - 1) * A_PtrSize, "Ptr"))
    return layouts
}

SwitchToEnglish(hwnd, tid) {
    global lastEnglishHkl
    target := 0
    layouts := KeyboardLayouts()

    ; Сначала последний английский, который видели; иначе первый установленный.
    if (lastEnglishHkl) {
        for hkl in layouts {
            if ((hkl & 0xFFFF) = 0x0409 && hkl = lastEnglishHkl) {
                target := hkl
                break
            }
        }
    }
    if !target {
        for hkl in layouts {
            if ((hkl & 0xFFFF) = 0x0409) {
                target := hkl
                break
            }
        }
    }
    if !target
        return
    lastEnglishHkl := target
    SwitchToHkl(hwnd, tid, target)
}

SwitchToRussian(hwnd, tid) {
    for hkl in KeyboardLayouts() {
        if ((hkl & 0xFFFF) = 0x0419) {
            SwitchToHkl(hwnd, tid, hkl)
            return
        }
    }
}

SwitchToHkl(hwnd, tid, target) {
    DllCall("PostMessage", "Ptr", hwnd, "UInt", 0x0050, "Ptr", 0, "Ptr", target)
    ; Даём раскладке примениться до следующей клавиши аккорда.
    start := A_TickCount
    Loop {
        current := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
        if ((current & 0xFFFF) = (target & 0xFFFF))
            break
        if (A_TickCount - start > 50)
            break
        Sleep 5
    }
}
