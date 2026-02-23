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
    try FileDelete(LOG_FILE)
    try FileAppend("=== START " NowStr() " | PID=" DllCall("GetCurrentProcessId") " ===`n", LOG_FILE, "UTF-8")
}

Log(msg) {
    global LOG_ENABLED, LOG_FILE
    if !LOG_ENABLED
        return
    try FileAppend(NowStr() " | " msg "`n", LOG_FILE, "UTF-8")
}

LogWin(prefix := "") {
    try Log(prefix "ActiveWinTitle=" WinGetTitle("A"))
}

LogInit()

; =========================
; НАСТРОЙКИ (дефолты)
; =========================
global gSwitchAfterBreak      := true   ; обычный Break/Pause (без модификаторов) -> линия
global gSwitchAfterShiftBreak := true   ; Shift+Break/Pause -> выделение (перезапишется из INI в InitUI())
global gSwitchAfterCtrlBreak  := true   ; Ctrl+Break -> слово (перезапишется из INI в InitUI())

; защита от двойного срабатывания: CtrlBreak может триггерить и CtrlBreak, и Pause
global gSkipNextPause := false

; UI / INI
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

    Log("HOTKEY *Pause fired | skip=" (gSkipNextPause?1:0)
        " Ctrl=" (GetKeyState("Ctrl","P")?1:0)
        " Shift=" (GetKeyState("Shift","P")?1:0))
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
            Log("Convert: doSwitch=1 -> SwitchLayout()")
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

    ; пропускаем делимитеры справа
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

    ; идём влево до делимитера
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
            Log("ConvertWord doSwitch=1 -> SwitchLayout()")
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
; - любой символ, который НЕ буква/цифра/_
; ВАЖНО: ',' и '.' считаем частью слова (чтобы конвертилось "как есть")
IsDelimiterForWord(ch) {
    if RegExMatch(ch, "^\s$")
        return true
    return !RegExMatch(ch, "^[\p{L}\p{N}_,\.]$")
}

RestoreClipboard(savedClip) {
    A_Clipboard := savedClip
}

; =========================
; ПЕРЕКЛЮЧЕНИЕ РАСКЛАДКИ (ПРОСТО ALT+SHIFT)
; =========================
SwitchLayout() {
    ; Если в Windows не Alt+Shift — поменяй на свой хоткей.
    ; Пример для Win+Space:
    ; SendEvent "#{Space}"
    Log("SwitchLayout: send Alt+Shift")
    SendEvent "{Alt down}{Shift down}{Shift up}{Alt up}"
}

; =========================
; КОНВЕРТАЦИЯ РАСКЛАДКИ (ПРОСТАЯ, БЕЗ "УМНЫХ" ЗАПЯТЫХ/ТОЧЕК)
; =========================
ToggleLayout(str) {
    ; Если есть кириллица — считаем, что это "набрано в RU" и конвертим в EN
    if RegExMatch(str, "[А-Яа-яЁё]")
        return RuToEn(str)

    ; Если есть латиница — конвертим ВЕСЬ токен в RU (включая , . и т.п.)
    if RegExMatch(str, "[A-Za-z]")
        return EnToRu(str)

    return str
}

; =========================
; ТАБЛИЦЫ РАСКЛАДКИ (РУ ↔ EN) + РЕГИСТР + ЗНАКИ
; =========================
RuToEn(str) {
    ru := "ёйцукенгшщзхъфывапролджэячсмитьбю."
        . "ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"

    en := "``qwertyuiop[]asdfghjkl;'zxcvbnm,./"
        . "~QWERTYUIOP{}ASDFGHJKL:" . Chr(34) . "ZXCVBNM<>?"

    return MapLayout(str, ru, en)
}

EnToRu(str) {
    ru := "ёйцукенгшщзхъфывапролджэячсмитьбю."
        . "ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"

    en := "``qwertyuiop[]asdfghjkl;'zxcvbnm,./"
        . "~QWERTYUIOP{}ASDFGHJKL:" . Chr(34) . "ZXCVBNM<>?"

    return MapLayout(str, en, ru)
}

MapLayout(str, from, to) {
    out := ""
    for _, ch in StrSplit(str, "") {
        pos := InStr(from, ch, true) ; учитывать регистр
        out .= (pos > 0) ? SubStr(to, pos, 1) : ch
    }
    return out
}
