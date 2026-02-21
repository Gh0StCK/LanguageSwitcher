#Requires AutoHotkey v2.0+
#SingleInstance Force
#Include LanguageSwitcher_UI.ahk

; =========================
; ЛОГИ
; =========================
global LOG_ENABLED := false
global LOG_FILE := A_ScriptDir "\LanguageSwitcher.log"

NowStr() {
    ; 2026-02-21 18:22:33.123
    return FormatTime(, "yyyy-MM-dd HH:mm:ss") "." SubStr(A_MSec, 1, 3)
}

LogInit() {
    global LOG_ENABLED, LOG_FILE
    if !LOG_ENABLED
        return

    ; очищаем лог при запуске
    try FileDelete(LOG_FILE)

    ; пишем заголовок
    try FileAppend("=== START " NowStr() " | PID=" DllCall("GetCurrentProcessId") " ===`n", LOG_FILE, "UTF-8")
}

Log(msg) {
    global LOG_ENABLED, LOG_FILE
    if !LOG_ENABLED
        return
    try FileAppend(NowStr() " | " msg "`n", LOG_FILE, "UTF-8")
}

LogWin(prefix := "") {
    try {
        t := WinGetTitle("A")
        Log(prefix "ActiveWinTitle=" t)
    } catch {
        ; ignore
    }
}

LogInit()

; =========================
; НАСТРОЙКИ (дефолты)
; =========================
global gSwitchAfterBreak      := true   ; для обычного Break (без UI)
global gSwitchAfterShiftBreak := true   ; перезапишется из INI в InitUI()
global gSwitchAfterCtrlBreak  := true   ; перезапишется из INI в InitUI()

; защита от двойного срабатывания: CtrlBreak может триггерить и CtrlBreak, и Pause
global gSkipNextPause := false

global MyGui
InitUI()

Log("InitUI done | SwitchAfterShift=" (gSwitchAfterShiftBreak?1:0) " SwitchAfterCtrl=" (gSwitchAfterCtrlBreak?1:0))
LogWin("AfterInitUI | ")

; =========================
; ХОТКЕИ
; =========================

; Если в системе реально приходит CtrlBreak — он будет работать тут
^CtrlBreak:: {
    global gSkipNextPause, gSwitchAfterCtrlBreak
    Log("HOTKEY ^CtrlBreak fired | doSwitch=" (gSwitchAfterCtrlBreak?1:0))
    LogWin("HOTKEY ^CtrlBreak | ")

    gSkipNextPause := true
    SetTimer (() => (gSkipNextPause := false)), -80

    Convert("word", gSwitchAfterCtrlBreak)
}

; Универсальный ловец Pause/Break
*Pause:: {
    global gSkipNextPause, gSwitchAfterCtrlBreak, gSwitchAfterShiftBreak, gSwitchAfterBreak

    Log("HOTKEY *Pause fired | skip=" (gSkipNextPause?1:0) " Ctrl=" (GetKeyState("Ctrl","P")?1:0) " Shift=" (GetKeyState("Shift","P")?1:0))
    LogWin("HOTKEY *Pause | ")

    if gSkipNextPause
        return

    if GetKeyState("Ctrl", "P")
        Convert("word", gSwitchAfterCtrlBreak)
    else if GetKeyState("Shift", "P")
        Convert("selection", gSwitchAfterShiftBreak)
    else
        Convert("line", gSwitchAfterBreak)
}

; =========================
; ОСНОВНАЯ ЛОГИКА
; =========================
Convert(mode := "selection", doSwitch := true) {
    Critical
    Log("Convert enter | mode=" mode " doSwitch=" (doSwitch?1:0))

    if (mode = "word") {
        ConvertWordBeforeCursor(doSwitch)
        return
    }

    saved  := ClipboardAll()
    marker := "#LS_MARKER_" A_TickCount "#"
    A_Clipboard := marker

    if (mode = "line") {
        Log("Convert line: selecting from cursor to line start")
        SendEvent "+{Home}"
        Sleep 10
        SendEvent "+{Home}"
        Sleep 25
    }

    SendEvent "^c"
    if !ClipWait(0.6) {
        Log("Convert FAIL: ClipWait timeout")
        RestoreClipboard(saved)
        return
    }

    if (A_Clipboard = marker) {
        Log("Convert exit: no selection (clipboard marker unchanged)")
        RestoreClipboard(saved)
        return
    }

    sel := A_Clipboard
    Log("Convert copied len=" StrLen(sel))

    if (sel = "") {
        Log("Convert exit: selection empty")
        RestoreClipboard(saved)
        return
    }

    conv := ToggleLayout(sel)

    if (conv = sel) {
        Log("Convert: conv==sel (no changes)")
        if (doSwitch) {
            Log("Convert: doSwitch=1 -> SwitchLayout() even if no changes")
            SwitchLayout()
        } else {
            Log("Convert: doSwitch=0 -> skip SwitchLayout")
        }
        RestoreClipboard(saved)
        return
    }

    A_Clipboard := conv
    Sleep 20
    SendEvent "^v"
    Log("Convert pasted")

    if (doSwitch) {
        Log("Convert doSwitch=1 -> SwitchLayout()")
        SwitchLayout()
    } else {
        Log("Convert doSwitch=0 -> skip SwitchLayout")
    }

    SetTimer RestoreClipboard.Bind(saved), -150
}

ConvertWordBeforeCursor(doSwitch := true) {
    Critical
    Log("ConvertWord enter | doSwitch=" (doSwitch?1:0))

    saved  := ClipboardAll()
    marker := "#LS_MARKER_" A_TickCount "#"
    A_Clipboard := marker

    ; берём всё слева от курсора до начала строки
    SendEvent "+{Home}"
    Sleep 10
    SendEvent "+{Home}"
    Sleep 25

    SendEvent "^c"
    if !ClipWait(0.6) {
        Log("ConvertWord FAIL: ClipWait timeout (pre)")
        RestoreClipboard(saved)
        return
    }
    if (A_Clipboard = marker) {
        Log("ConvertWord exit: marker unchanged (no selection?)")
        RestoreClipboard(saved)
        return
    }

    pre := A_Clipboard
    origEnd := StrLen(pre)
    Log("ConvertWord pre len=" origEnd)

    if (origEnd = 0) {
        SendEvent "{Right}"
        Log("ConvertWord exit: pre empty")
        RestoreClipboard(saved)
        return
    }

    ; пропускаем делимитеры справа (кроме , .)
    i := origEnd
    while (i > 0) {
        ch := SubStr(pre, i, 1)
        if IsDelimiterForWord(ch)
            i -= 1
        else
            break
    }
    endPos := i
    Log("ConvertWord endPos=" endPos)

    if (endPos <= 0) {
        SendEvent "{Right}"
        Log("ConvertWord exit: endPos<=0 (only delimiters)")
        RestoreClipboard(saved)
        return
    }

    ; идём влево до делимитера (кроме , .)
    j := endPos
    while (j > 0) {
        ch := SubStr(pre, j, 1)
        if IsDelimiterForWord(ch) {
            j += 1
            break
        }
        j -= 1
    }
    startPos := (j = 0) ? 1 : j

    wordLen  := endPos - startPos + 1
    skipTail := origEnd - endPos
    Log("ConvertWord startPos=" startPos " wordLen=" wordLen " skipTail=" skipTail)

    ; вернуть курсор в исходную позицию
    SendEvent "{Right}"
    Sleep 10

    if (skipTail > 0) {
        SendEvent "{Left " skipTail "}"
        Sleep 10
        Log("ConvertWord moved left by skipTail")
    }

    SendEvent "+{Left " wordLen "}"
    Sleep 20
    Log("ConvertWord selected word (by keys)")

    marker2 := marker "_W"
    A_Clipboard := marker2
    SendEvent "^c"
    if !ClipWait(0.6) {
        Log("ConvertWord FAIL: ClipWait timeout (word)")
        RestoreClipboard(saved)
        return
    }
    if (A_Clipboard = marker2) {
        Log("ConvertWord exit: marker2 unchanged (word selection failed)")
        RestoreClipboard(saved)
        return
    }

    sel := A_Clipboard
    Log("ConvertWord copied word len=" StrLen(sel) " text='" ShortText(sel) "'")

    if (sel = "") {
        Log("ConvertWord exit: word empty")
        RestoreClipboard(saved)
        return
    }

    conv := ToggleLayout(sel)

    if (conv = sel) {
        Log("ConvertWord conv==sel (no changes)")
        if (doSwitch) {
            Log("ConvertWord doSwitch=1 -> SwitchLayout() even if no changes")
            SwitchLayout()
        } else {
            Log("ConvertWord doSwitch=0 -> skip SwitchLayout")
        }
        RestoreClipboard(saved)
        return
    }

    A_Clipboard := conv
    Sleep 20
    SendEvent "^v"
    Log("ConvertWord pasted")

    if (doSwitch) {
        Log("ConvertWord doSwitch=1 -> SwitchLayout()")
        SwitchLayout()
    } else {
        Log("ConvertWord doSwitch=0 -> skip SwitchLayout")
    }

    SetTimer RestoreClipboard.Bind(saved), -150
}

ShortText(s, maxLen := 40) {
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    return (StrLen(s) <= maxLen) ? s : (SubStr(s, 1, maxLen) "…")
}

; Делимитер для "слова":
; - пробел/таб и т.п.
; - любой символ, который НЕ буква/цифра/_/,/.
; (важно: ',' и '.' НЕ делимитеры)
IsDelimiterForWord(ch) {
    if RegExMatch(ch, "^\s$")
        return true
    return !RegExMatch(ch, "^[\p{L}\p{N}_,\.]$")
}

RestoreClipboard(savedClip) {
    A_Clipboard := savedClip
}

SwitchLayout() {
    ; Переключаем раскладку через Windows message, а не имитацией клавиш.
    ; Работает даже если Ctrl/Shift зажаты.
    hwnd := WinExist("A")
    if !hwnd {
        try Log("SwitchLayout: no active hwnd")
        return
    }

    curHKL := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
    curLang := curHKL & 0xFFFF

    layouts := GetKeyboardLayouts()
    if (layouts.Length < 2) {
        try Log("SwitchLayout: only one layout detected")
        return
    }

    ; Пытаемся переключать именно RU <-> EN.
    ; RU = 0x0419, EN (US) = 0x0409
    wantLang := (curLang = 0x0419) ? 0x0409 : 0x0419
    targetHKL := FindHKLByLang(layouts, wantLang)

    ; Если нужного языка нет — просто циклим следующий по списку
    if !targetHKL
        targetHKL := NextHKL(layouts, curHKL)

    try Log(Format("SwitchLayout: curLang=0x{:04X} wantLang=0x{:04X} curHKL=0x{:X} targetHKL=0x{:X}",
        curLang, wantLang, curHKL, targetHKL))

    ; WM_INPUTLANGCHANGEREQUEST = 0x0050
    ; wParam=0, lParam=HKL
    try {
        SendMessage(0x0050, 0, targetHKL, , "ahk_id " hwnd)
        try Log("SwitchLayout: SendMessage WM_INPUTLANGCHANGEREQUEST OK")
    } catch as e {
        try Log("SwitchLayout: SendMessage failed: " e.Message)
    }

    ; На всякий случай (не всегда нужно, но не мешает)
    try DllCall("ActivateKeyboardLayout", "Ptr", targetHKL, "UInt", 0)
}

GetKeyboardLayouts() {
    n := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    buf := Buffer(A_PtrSize * n, 0)
    DllCall("GetKeyboardLayoutList", "Int", n, "Ptr", buf, "Int")

    arr := []
    Loop n {
        hkl := NumGet(buf, (A_Index - 1) * A_PtrSize, "Ptr")
        arr.Push(hkl)
    }
    return arr
}

FindHKLByLang(layouts, langId) {
    for _, hkl in layouts {
        if ((hkl & 0xFFFF) = langId)
            return hkl
    }
    return 0
}

NextHKL(layouts, curHKL) {
    ; циклим следующий после текущего
    idx := 0
    for i, hkl in layouts {
        if (hkl = curHKL) {
            idx := i
            break
        }
    }
    if (idx = 0)
        return layouts[1]
    next := idx + 1
    if (next > layouts.Length)
        next := 1
    return layouts[next]
}

ToggleLayout(str) {
    ; 1) Сохраняем хвостовую пунктуацию/пробелы как есть
    tail := ""
    while (str != "") {
        ch := SubStr(str, -1)  ; последний символ
        ; всё, что НЕ буква/цифра/_ — считаем "хвостом" (пунктуация/пробелы)
        if RegExMatch(ch, "^[^\p{L}\p{N}_]$") {
            tail := ch . tail
            str := SubStr(str, 1, StrLen(str) - 1)
        } else {
            break
        }
    }

    core := str
    if (core = "")
        return tail

    ; 2) Конвертируем только ядро
    if RegExMatch(core, "[А-Яа-яЁё]")
        conv := RuToEn(core)
    else if RegExMatch(core, "[A-Za-z]")
        conv := EnToRu(core)
    else
        conv := core

    ; 3) Возвращаем ядро + хвост
    return conv . tail
}

; =========================
; ТАБЛИЦЫ РАСКЛАДКИ (РУ ↔ EN) + РЕГИСТР + ЗНАКИ
; =========================
RuToEn(str) {
    ru := "ёйцукенгшщзхъфывапролджэячсмитьбю."
        . "ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"

    en := "``qwertyuiop[]asdfghjkl;'zxcvbnm,./"
        . "~QWERTYUIOP{}ASDFGHJKL:" . Chr(34) . "ZXCVBNM<>?"

    P_COMMA := Chr(0xE010)
    P_DOT   := Chr(0xE011)
    P_QUOTE := Chr(0xE012)

    s := StrReplace(str, ",", P_COMMA)
    s := StrReplace(s, ".", P_DOT)
    s := StrReplace(s, Chr(34), P_QUOTE)

    conv := MapLayout(s, ru, en)

    conv := StrReplace(conv, P_COMMA, ",")
    conv := StrReplace(conv, P_DOT,   ".")
    conv := StrReplace(conv, P_QUOTE, Chr(34))

    return conv
}

EnToRu(str) {
    ru := "ёйцукенгшщзхъфывапролджэячсмитьбю."
        . "ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"

    en := "``qwertyuiop[]asdfghjkl;'zxcvbnm,./"
        . "~QWERTYUIOP{}ASDFGHJKL:" . Chr(34) . "ZXCVBNM<>?"

    ; placeholders (Private Use Area)
    P_COMMA := Chr(0xE000)
    P_DOT   := Chr(0xE001)
    P_QUOTE := Chr(0xE002)

    out := ""
    token := ""

    ; режем по пробельным, чтобы анализировать "слова" отдельно
    Loop Parse str {
        ch := A_LoopField
        if RegExMatch(ch, "^\s$") {
            if (token != "")
                out .= EnToRu_ProcessToken(token, en, ru, P_COMMA, P_DOT, P_QUOTE)
            out .= ch
            token := ""
        } else {
            token .= ch
        }
    }
    if (token != "")
        out .= EnToRu_ProcessToken(token, en, ru, P_COMMA, P_DOT, P_QUOTE)

    return out
}

EnToRu_ProcessToken(token, en, ru, P_COMMA, P_DOT, P_QUOTE) {
    ; 1) кавычки всегда оставляем кавычками
    token2 := StrReplace(token, Chr(34), P_QUOTE)

    ; 2) умные запятые:
    ; - one,two,three  -> запятые пунктуация (не превращаем в 'б')
    ; - test,more      -> запятая пунктуация
    ; - j,jqnb         -> запятая = буква 'б' (разрешаем), т.к. слева/справа буквы и одна из частей длиной 1

    partsC := StrSplit(token2, ",")
    commaCount := partsC.Length - 1
    protectComma := false

    if (commaCount >= 2) {
        ; списки через запятую
        protectComma := true
        for _, p in partsC {
            if (StrLen(p) < 2) {
                protectComma := false
                break
            }
        }
    } else if (commaCount = 1) {
        left  := partsC[1]
        right := partsC[2]

        ; Разрешаем ','->'б' ТОЛЬКО если это "j,jqnb"-подобный кейс
        allowCommaAsLetter := RegExMatch(left, "^[A-Za-z]+$") && RegExMatch(right, "^[A-Za-z]+$")
            && (StrLen(left) = 1 || StrLen(right) = 1)

        protectComma := !allowCommaAsLetter
    }

    if protectComma
        token2 := StrReplace(token2, ",", P_COMMA)

    ; 3) умные точки:
    ;    если токен выглядит как "дот-идентификатор" (ghbdtn.txt / one.two.three) → НЕ конвертим точки
    partsD := StrSplit(token2, ".")
    dotCount := partsD.Length - 1
    protectDot := false
    if (dotCount >= 1) {
        protectDot := true
        for _, p in partsD {
            if (StrLen(p) < 2) {
                protectDot := false
                break
            }
        }
    }
    if protectDot
        token2 := StrReplace(token2, ".", P_DOT)

    ; 4) конвертируем раскладку
    conv := MapLayout(token2, en, ru)

    ; 5) возвращаем защищённую пунктуацию
    conv := StrReplace(conv, P_COMMA, ",")
    conv := StrReplace(conv, P_DOT,   ".")
    conv := StrReplace(conv, P_QUOTE, Chr(34))

    return conv
}

MapLayout(str, from, to) {
    out := ""
    for _, ch in StrSplit(str, "") {
        pos := InStr(from, ch, true)  ; учитывать регистр
        out .= (pos > 0) ? SubStr(to, pos, 1) : ch
    }
    return out
}