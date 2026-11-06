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
global capsSynth := false

~LControl::
{
    global
    if (capsSynth)
        return
    if (ctrlActive)
        return
    ctrlActive := true
    ctrlUsed := false
    ctrlDownTime := A_TickCount
    wasRussian := false

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if !tid
        return
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
    if (capsSynth)
        return
    ctrlActive := false

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

; CapsLock: одиночное нажатие — Esc, аккорд — Ctrl. Драйвер больше не
; переводит CapsLock в Esc (scancode-map.ps1), иначе AHK не увидит клавишу.
*CapsLock::
{
    global
    if (capsActive)
        return
    capsActive := true
    capsUsed := false
    capsWasRussian := false
    capsDownTime := A_TickCount

    ; Ctrl — сразу, чтобы первая клавиша аккорда уже шла с модификатором.
    SendSynth("{Blind}{LControl Down}")

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

*CapsLock Up::
{
    global
    capsActive := false
    SendSynth("{Blind}{LControl Up}")

    if (A_PriorKey != "CapsLock" && A_PriorKey != "LControl" && A_PriorKey != "Control")
        capsUsed := true

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    tid := 0
    if hwnd
        tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if (capsWasRussian && hwnd && tid)
        SwitchToRussian(hwnd, tid)

    if (!capsUsed)
        SendSynth("{Esc}")

    capsUsed := false
    capsWasRussian := false
}

; Как Cmd+Shift+[ / ] на маке: Ctrl+Shift+[ — предыдущая вкладка, Ctrl+Shift+] —
; следующая. Скан-коды, чтобы работало и на русской раскладке (х/ъ).
^+SC01A::Send "^+{Tab}"
^+SC01B::Send "^{Tab}"

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
}

; Синтетический ввод на SendLevel 1; ~LControl его пропускает по capsSynth.
SendSynth(keys) {
    global capsSynth
    capsSynth := true
    SendLevel 1
    Send keys
    SendLevel 0
    capsSynth := false
}

CapsWatchdog() {
    global
    if (capsActive && A_TickCount - capsDownTime > 8000) {
        capsActive := false
        SendSynth("{Blind}{LControl Up}")
        capsUsed := false
        capsWasRussian := false
    }
}

CapsRelease(*) {
    global
    if (capsActive) {
        capsActive := false
        SendSynth("{Blind}{LControl Up}")
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
