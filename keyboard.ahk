; Одиночный Ctrl переключает язык; Ctrl-аккорд на русской раскладке
; временно уходит в английский и после аккорда возвращается обратно.
; CapsLock: одиночное нажатие — Esc, удержание в аккорде — Ctrl с тем же
; временным английским. Перестановка модификаторов — в ScanCode Map.
#NoEnv
#SingleInstance force
SetWorkingDir %A_ScriptDir%

SetCapsLockState, AlwaysOff
OnExit, CapsRelease
SetTimer, CapsWatchdog, 500

ctrlUsed := false
ctrlActive := false
ctrlDownTime := 0
wasRussian := false
lastToggle := 0
lastEnglishHkl := 0
capsActive := false
capsUsed := false
capsWasRussian := false
capsDownTime := 0
capsSynth := false

~LControl::
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
    thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if !thread
        return
    current := DllCall("GetKeyboardLayout", "UInt", thread, "Ptr")
    lang := current & 0xFFFF
    if (lang = 0x0419) {
        wasRussian := true
        SwitchToEnglish(hwnd, thread)
    } else if (lang = 0x0409) {
        lastEnglishHkl := current
    }
return

~LControl Up::
    if (capsSynth)
        return
    ctrlActive := false

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    thread := 0
    if hwnd
        thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")

    if (ctrlUsed) {
        if (wasRussian && hwnd && thread)
            SwitchToRussian(hwnd, thread)
        ctrlUsed := false
        wasRussian := false
        return
    }

    ; Аккорд: нажата другая клавиша или ещё один модификатор.
    if (A_PriorKey != "LControl" && A_PriorKey != "Control") {
        if (wasRussian && hwnd && thread)
            SwitchToRussian(hwnd, thread)
        wasRussian := false
        return
    }
    if (GetKeyState("Shift", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P")) {
        if (wasRussian && hwnd && thread)
            SwitchToRussian(hwnd, thread)
        wasRussian := false
        return
    }

    ; Долгое удержание — не одиночное нажатие.
    if (A_TickCount - ctrlDownTime > 600) {
        if (wasRussian && hwnd && thread)
            SwitchToRussian(hwnd, thread)
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
    } else if (hwnd && thread) {
        SwitchToRussian(hwnd, thread)
    }
    wasRussian := false
return

; CapsLock: одиночное нажатие — Esc, аккорд — Ctrl. Драйвер больше не
; переводит CapsLock в Esc (scancode-map.ps1), иначе AHK не увидит клавишу.
*CapsLock::
    if (capsActive)
        return
    capsActive := true
    capsUsed := false
    capsWasRussian := false
    capsDownTime := A_TickCount

    ; Ctrl — сразу, чтобы первая клавиша аккорда уже шла с модификатором.
    capsSynth := true
    SendLevel, 1
    Send {Blind}{LControl Down}
    SendLevel, 0
    capsSynth := false

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return
    thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if !thread
        return
    current := DllCall("GetKeyboardLayout", "UInt", thread, "Ptr")
    if ((current & 0xFFFF) = 0x0419) {
        capsWasRussian := true
        SwitchToEnglish(hwnd, thread)
    }
return

*CapsLock Up::
    capsActive := false
    capsSynth := true
    SendLevel, 1
    Send {Blind}{LControl Up}
    SendLevel, 0
    capsSynth := false

    if (A_PriorKey != "CapsLock" && A_PriorKey != "LControl" && A_PriorKey != "Control")
        capsUsed := true

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    thread := 0
    if hwnd
        thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if (capsWasRussian && hwnd && thread)
        SwitchToRussian(hwnd, thread)

    if (!capsUsed) {
        capsSynth := true
        SendLevel, 1
        Send {Esc}
        SendLevel, 0
        capsSynth := false
    }

    capsUsed := false
    capsWasRussian := false
return

CapsWatchdog:
    if (capsActive && A_TickCount - capsDownTime > 8000) {
        capsActive := false
        capsSynth := true
        SendLevel, 1
        Send {Blind}{LControl Up}
        SendLevel, 0
        capsSynth := false
        capsUsed := false
        capsWasRussian := false
    }
return

CapsRelease:
    if (capsActive) {
        capsActive := false
        capsSynth := true
        SendLevel, 1
        Send {Blind}{LControl Up}
        SendLevel, 0
        capsSynth := false
    }
return

; Мышь с зажатым Ctrl — не одиночное нажатие.
~*LButton::
~*RButton::
~*MButton::
~*WheelUp::
~*WheelDown::
    if GetKeyState("Ctrl", "P")
        ctrlUsed := true
return

SwitchToEnglish(hwnd, thread) {
    global lastEnglishHkl
    target := 0
    count := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0)
    if (count <= 0)
        return
    VarSetCapacity(list, count * A_PtrSize, 0)
    DllCall("GetKeyboardLayoutList", "Int", count, "Ptr", &list)

    ; Сначала последний английский, который видели; иначе первый установленный.
    if (lastEnglishHkl) {
        Loop, %count% {
            hkl := NumGet(list, (A_Index - 1) * A_PtrSize, "Ptr")
            if ((hkl & 0xFFFF) = 0x0409 && hkl = lastEnglishHkl) {
                target := hkl
                break
            }
        }
    }
    if !target {
        Loop, %count% {
            hkl := NumGet(list, (A_Index - 1) * A_PtrSize, "Ptr")
            if ((hkl & 0xFFFF) = 0x0409) {
                target := hkl
                break
            }
        }
    }
    if !target
        return
    lastEnglishHkl := target
    SwitchToHkl(hwnd, thread, target)
}

SwitchToRussian(hwnd, thread) {
    count := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0)
    if (count <= 0)
        return
    VarSetCapacity(list, count * A_PtrSize, 0)
    DllCall("GetKeyboardLayoutList", "Int", count, "Ptr", &list)
    target := 0
    Loop, %count% {
        hkl := NumGet(list, (A_Index - 1) * A_PtrSize, "Ptr")
        if ((hkl & 0xFFFF) = 0x0419) {
            target := hkl
            break
        }
    }
    if !target
        return
    SwitchToHkl(hwnd, thread, target)
}

SwitchToHkl(hwnd, thread, target) {
    DllCall("PostMessage", "Ptr", hwnd, "UInt", 0x0050, "Ptr", 0, "Ptr", target)
    ; Даём раскладке примениться до следующей клавиши аккорда.
    start := A_TickCount
    Loop {
        current := DllCall("GetKeyboardLayout", "UInt", thread, "Ptr")
        if ((current & 0xFFFF) = (target & 0xFFFF))
            break
        if (A_TickCount - start > 50)
            break
        Sleep 5
    }
}
