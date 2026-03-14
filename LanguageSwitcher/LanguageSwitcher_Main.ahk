#Requires AutoHotkey v2.0+
#SingleInstance Force
#ClipboardTimeout 700
#Include LanguageSwitcher_UI.ahk

; =========================
; ЛОГИ
; =========================
global LOG_ENABLED := false
global LOG_FILE := A_ScriptDir "\LanguageSwitcher.log"

NowStr() {
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

ShortText(s, maxLen := 80) {
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    return (StrLen(s) <= maxLen) ? s : (SubStr(s, 1, maxLen) "…")
}

LogInit()

; =========================
; НАСТРОЙКИ
; =========================
global gSwitchAfterBreak      := true   ; Break/Pause -> строка слева от курсора
global gSwitchAfterShiftBreak := true   ; Shift+Break -> выделение
global gSwitchAfterCtrlBreak  := true   ; Ctrl+Break -> токен перед курсором

global gSkipNextPause := false
global gBusy := false
global MyGui

; Lang IDs (НЕ грузим раскладки, только ищем среди уже установленных)
global LANGID_EN := 0x0409   ; English (US)
global LANGID_RU := 0x0419   ; Russian
global LANGID_PL := 0x0415   ; Polish (на всякий)

; HKL handles (берём только из уже установленного списка)
global gHKL_EN := 0
global gHKL_RU := 0

; =========================
; ИНИЦИАЛИЗАЦИЯ
; =========================
InitKeyboardLayouts()  ; НЕ добавляет раскладки, только ищет
InitUI()

Log("InitUI done | SwitchAfterShift=" (gSwitchAfterShiftBreak ? 1 : 0)
    " SwitchAfterCtrl=" (gSwitchAfterCtrlBreak ? 1 : 0))
LogWin("AfterInitUI | ")

; =========================
; ТАБЛИЦЫ РАСКЛАДКИ
; =========================
; Верхний ряд с Shift:
; !@#$%^&*()_+ <-> !"№;%:?*()_+
global gRuKeys := "ё1234567890-=йцукенгшщзхъфывапролджэячсмитьбю."
    . "Ё!" . Chr(34) . "№;%:?*()_+ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"

global gEnKeys := "``1234567890-=qwertyuiop[]asdfghjkl;'zxcvbnm,./"
    . "~!@#$%^&*()_+QWERTYUIOP{}ASDFGHJKL:" . Chr(34) . "ZXCVBNM<>?"

; =========================
; HKL: ТОЛЬКО ПОИСК УЖЕ УСТАНОВЛЕННЫХ (БЕЗ LoadKeyboardLayoutW)
; =========================
FindHKLByLangId(langId) {
    cnt := DllCall("user32\GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    if (cnt <= 0)
        return 0

    buf := Buffer(A_PtrSize * cnt, 0)
    DllCall("user32\GetKeyboardLayoutList", "Int", cnt, "Ptr", buf, "Int")

    Loop cnt {
        hkl := NumGet(buf, (A_Index - 1) * A_PtrSize, "Ptr")
        if ((hkl & 0xFFFF) = langId)
            return hkl
    }
    return 0
}

InitKeyboardLayouts() {
    global LANGID_EN, LANGID_RU, gHKL_EN, gHKL_RU

    Log("InitKeyboardLayouts enter | (no LoadKeyboardLayoutW, only GetKeyboardLayoutList)")

    gHKL_EN := FindHKLByLangId(LANGID_EN)
    gHKL_RU := FindHKLByLangId(LANGID_RU)

    Log("InitKeyboardLayouts done | HKL_EN=" (gHKL_EN ? Format("0x{:X}", gHKL_EN) : "0")
        " HKL_RU=" (gHKL_RU ? Format("0x{:X}", gHKL_RU) : "0"))
}

; =========================
; ХОТКЕИ
; =========================
^CtrlBreak:: {
    global gSkipNextPause, gSwitchAfterCtrlBreak, gBusy

    if gBusy {
        Log("HOTKEY ^CtrlBreak ignored: gBusy=1")
        return
    }

    Log("HOTKEY ^CtrlBreak fired | doSwitch=" (gSwitchAfterCtrlBreak ? 1 : 0))
    LogWin("HOTKEY ^CtrlBreak | ")

    gSkipNextPause := true
    SetTimer ClearSkipPause, -80

    Convert("token", gSwitchAfterCtrlBreak)
}

*Pause:: {
    global gSkipNextPause
    global gSwitchAfterBreak, gSwitchAfterShiftBreak, gSwitchAfterCtrlBreak
    global gBusy

    Log("HOTKEY *Pause fired | skip=" (gSkipNextPause ? 1 : 0)
        " Ctrl=" (GetKeyState("Ctrl", "P") ? 1 : 0)
        " Shift=" (GetKeyState("Shift", "P") ? 1 : 0))
    LogWin("HOTKEY *Pause | ")

    if gBusy {
        Log("HOTKEY *Pause ignored: gBusy=1")
        return
    }

    if gSkipNextPause {
        Log("HOTKEY *Pause exit: skipped by gSkipNextPause")
        return
    }

    if GetKeyState("Ctrl", "P") {
        Log("HOTKEY *Pause route -> token")
        Convert("token", gSwitchAfterCtrlBreak)
    } else if GetKeyState("Shift", "P") {
        Log("HOTKEY *Pause route -> selection")
        Convert("selection", gSwitchAfterShiftBreak)
    } else {
        Log("HOTKEY *Pause route -> line")
        Convert("line", gSwitchAfterBreak)
    }
}

ClearSkipPause() {
    global gSkipNextPause
    gSkipNextPause := false
    Log("ClearSkipPause -> 0")
}

; =========================
; ОСНОВНАЯ ЛОГИКА
; =========================
Convert(mode := "selection", doSwitch := true) {
    global gBusy
    Critical
    gBusy := true

    Log("Convert enter | mode=" mode " doSwitch=" (doSwitch ? 1 : 0))

    try {
        if (mode = "token") {
            ConvertTokenBeforeCursor(doSwitch)
            return
        }

        saved := ClipboardAll()
        pasted := false
        createdSelection := false

        try {
            if (mode = "line") {
                SendEvent "+{Home}"
                Sleep 15
                SendEvent "+{Home}"
                Sleep 25
                createdSelection := true
                Log("Convert line: selected from cursor to line start")
            }

            text := CopyCurrentSelection()
            if (text = "") {
                Log("Convert exit: copied text is empty -> no convert, no layout switch")
                return
            }

            result := ConvertLayout(text)
            Log("Convert copied='" ShortText(text) "' -> '" ShortText(result.text) "' | target=" result.target)

            if (result.text != text) {
                A_Clipboard := result.text
                Sleep 20
                SendEvent "^v"
                pasted := true
                Log("Convert pasted")
                Sleep 40
            } else {
                Log("Convert no changes")
            }

            ApplyLayoutAfterConvert(doSwitch, result.target)

        } catch as e {
            Log("Convert ERROR | mode=" mode " | " e.Message)
        } finally {
            if createdSelection && !pasted {
                CollapseSelectionToRight()
                Log("Convert cleanup: collapsed selection to right")
            }

            RestoreClipboard(saved)
            Log("Convert exit")
        }
    } finally {
        gBusy := false
        Log("Convert final | gBusy=0")
    }
}

ConvertTokenBeforeCursor(doSwitch := true) {
    Log("ConvertToken enter | doSwitch=" (doSwitch ? 1 : 0))

    saved := ClipboardAll()
    pasted := false
    tempSelectionActive := false
    tokenSelectionActive := false

    try {
        SendEvent "+{Home}"
        Sleep 15
        SendEvent "+{Home}"
        Sleep 25
        tempSelectionActive := true

        pre := CopyCurrentSelection()
        if (pre = "") {
            Log("ConvertToken exit: marker unchanged or empty pre -> no convert, no layout switch")
            return
        }

        Log("ConvertToken pre len=" StrLen(pre) " text='" ShortText(pre) "'")

        CollapseSelectionToRight()
        tempSelectionActive := false
        Sleep 10

        endPos := TrimRightWhitespacePos(pre)
        if (endPos <= 0) {
            Log("ConvertToken exit: only whitespace before cursor -> no convert, no layout switch")
            return
        }

        startPos := FindTokenStart(pre, endPos)
        tokenLen := endPos - startPos + 1
        skipSpaces := StrLen(pre) - endPos

        Log("ConvertToken startPos=" startPos " tokenLen=" tokenLen " skipSpaces=" skipSpaces)

        if (skipSpaces > 0) {
            SendEvent "{Left " skipSpaces "}"
            Sleep 10
            Log("ConvertToken moved left by skipSpaces")
        }

        SendEvent "+{Left " tokenLen "}"
        Sleep 20
        tokenSelectionActive := true
        Log("ConvertToken selected token")

        text := CopyCurrentSelection()
        if (text = "") {
            Log("ConvertToken exit: token copy failed / empty -> no convert, no layout switch")
            return
        }

        result := ConvertLayout(text)
        Log("ConvertToken copied='" ShortText(text) "' -> '" ShortText(result.text) "' | target=" result.target)

        if (result.text != text) {
            A_Clipboard := result.text
            Sleep 20
            SendEvent "^v"
            pasted := true
            Log("ConvertToken pasted")
            Sleep 40
        } else {
            Log("ConvertToken no changes")
        }

        ApplyLayoutAfterConvert(doSwitch, result.target)

    } catch as e {
        Log("ConvertToken ERROR | " e.Message)
    } finally {
        if tempSelectionActive || (tokenSelectionActive && !pasted) {
            CollapseSelectionToRight()
            Log("ConvertToken cleanup: collapsed selection to right")
        }

        RestoreClipboard(saved)
        Log("ConvertToken exit")
    }
}

CopyCurrentSelection() {
    marker := "#LS_MARKER_" A_TickCount "#"
    A_Clipboard := marker
    SendEvent "^c"

    if !ClipWait(0.6) {
        Log("CopyCurrentSelection FAIL: ClipWait timeout")
        return ""
    }

    if (A_Clipboard = marker) {
        Log("CopyCurrentSelection FAIL: clipboard marker unchanged")
        return ""
    }

    ; Защита от случайного попадания маркера в текст
    if InStr(A_Clipboard, "#LS_MARKER_") || InStr(A_Clipboard, "№ДЫ_ЬФКЛУК_") {
        Log("CopyCurrentSelection FAIL: marker-like text detected -> '" ShortText(A_Clipboard) "'")
        return ""
    }

    Log("CopyCurrentSelection OK | len=" StrLen(A_Clipboard) " text='" ShortText(A_Clipboard) "'")
    return A_Clipboard
}

TrimRightWhitespacePos(text) {
    i := StrLen(text)
    while (i > 0) {
        ch := SubStr(text, i, 1)
        if RegExMatch(ch, "^\s$")
            i -= 1
        else
            break
    }
    return i
}

FindTokenStart(text, endPos) {
    i := endPos
    while (i > 0) {
        ch := SubStr(text, i, 1)
        if RegExMatch(ch, "^\s$")
            break
        i -= 1
    }
    return i + 1
}

CollapseSelectionToRight() {
    SendEvent "{Right}"
}

RestoreClipboard(savedClip) {
    A_Clipboard := savedClip
    Log("RestoreClipboard done")
}

; =========================
; ПРИМЕНЕНИЕ НУЖНОЙ РАСКЛАДКИ
; =========================
ApplyLayoutAfterConvert(doSwitch, targetHint := "") {
    Log("ApplyLayoutAfterConvert enter | doSwitch=" (doSwitch ? 1 : 0) " targetHint=" targetHint)

    if !doSwitch {
        Log("ApplyLayoutAfterConvert exit: doSwitch=0")
        return
    }

    if (targetHint != "") {
        if SwitchToLayout(targetHint) {
            Log("ApplyLayoutAfterConvert success via targetHint=" targetHint)
            return
        } else {
            Log("ApplyLayoutAfterConvert targetHint switch failed")
        }
    }

    ToggleEnRuForActiveWindow()
}

SwitchToLayout(target) {
    global gHKL_EN, gHKL_RU

    hwnd := WinExist("A")
    if !hwnd {
        Log("SwitchToLayout FAIL: no active hwnd")
        return false
    }

    targetHKL := 0
    if (target = "ru")
        targetHKL := gHKL_RU
    else if (target = "en")
        targetHKL := gHKL_EN
    else {
        Log("SwitchToLayout FAIL: unknown target=" target)
        return false
    }

    ; ВАЖНО: если раскладка не установлена в Windows — HKL будет 0, и мы НИЧЕГО НЕ ДОБАВЛЯЕМ.
    if !targetHKL {
        Log("SwitchToLayout FAIL: targetHKL=0 for target=" target " (layout not installed?)")
        return false
    }

    try {
        Log("SwitchToLayout send | target=" target
            " hwnd=" hwnd
            " HKL=" Format("0x{:X}", targetHKL))

        ; WM_INPUTLANGCHANGEREQUEST = 0x0050
        SendMessage(0x0050, 0, targetHKL, , "ahk_id " hwnd)
        Sleep 20

        current := GetActiveWindowLang()
        ok := (current = target)

        Log("SwitchToLayout result | requested=" target " current=" current " ok=" (ok ? 1 : 0))
        return ok
    } catch as e {
        Log("SwitchToLayout ERROR | target=" target " | " e.Message)
        return false
    }
}

ToggleEnRuForActiveWindow() {
    current := GetActiveWindowLang()
    Log("ToggleEnRuForActiveWindow | current=" current)

    if (current = "ru")
        return SwitchToLayout("en")

    if (current = "en")
        return SwitchToLayout("ru")

    ; Если текущая раскладка другая (pl/unknown) — пробуем ru, если не вышло — en
    if SwitchToLayout("ru")
        return true

    return SwitchToLayout("en")
}

GetActiveWindowLang() {
    hwnd := WinExist("A")
    if !hwnd {
        Log("GetActiveWindowLang FAIL: no active hwnd")
        return ""
    }

    try {
        threadId := DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", 0, "UInt")
        if !threadId {
            Log("GetActiveWindowLang FAIL: threadId=0")
            return ""
        }

        hkl := DllCall("user32\GetKeyboardLayout", "UInt", threadId, "Ptr")
        if !hkl {
            Log("GetActiveWindowLang FAIL: hkl=0")
            return ""
        }

        langId := hkl & 0xFFFF

        if (langId = 0x0419)
            return "ru"
        if (langId = 0x0409)
            return "en"
        if (langId = 0x0415)
            return "pl"

        Log("GetActiveWindowLang -> unknown | langId=" Format("0x{:X}", langId))
        return ""
    } catch as e {
        Log("GetActiveWindowLang ERROR | " e.Message)
        return ""
    }
}

; =========================
; КОНВЕРТАЦИЯ РАСКЛАДКИ
; =========================
ConvertLayout(text) {
    toRu := EnToRu(text)
    toEn := RuToEn(text)

    toRuChanges := CountChanges(text, toRu)
    toEnChanges := CountChanges(text, toEn)

    latinCount := CountLatin(text)
    cyrCount   := CountCyr(text)

    Log("ConvertLayout analyze | text='" ShortText(text) "'"
        " toRuChanges=" toRuChanges
        " toEnChanges=" toEnChanges
        " latin=" latinCount
        " cyr=" cyrCount)

    if (toRuChanges > toEnChanges)
        return { text: toRu, target: "ru" }

    if (toEnChanges > toRuChanges)
        return { text: toEn, target: "en" }

    if (toRuChanges = 0)
        return { text: text, target: "" }

    if (latinCount > cyrCount)
        return { text: toRu, target: "ru" }

    if (cyrCount > latinCount)
        return { text: toEn, target: "en" }

    return { text: text, target: "" }
}

CountChanges(a, b) {
    len := StrLen(a)
    if (StrLen(b) < len)
        len := StrLen(b)

    count := 0
    Loop len {
        if (SubStr(a, A_Index, 1) != SubStr(b, A_Index, 1))
            count += 1
    }
    return count
}

CountLatin(text) {
    count := 0
    for _, ch in StrSplit(text, "")
        if RegExMatch(ch, "^[A-Za-z]$")
            count += 1
    return count
}

CountCyr(text) {
    count := 0
    for _, ch in StrSplit(text, "")
        if RegExMatch(ch, "^[А-Яа-яЁё]$")
            count += 1
    return count
}

RuToEn(text) {
    global gRuKeys, gEnKeys
    return MapLayout(text, gRuKeys, gEnKeys)
}

EnToRu(text) {
    global gRuKeys, gEnKeys
    return MapLayout(text, gEnKeys, gRuKeys)
}

MapLayout(text, fromChars, toChars) {
    out := ""
    for _, ch in StrSplit(text, "") {
        pos := InStr(fromChars, ch, true)
        out .= (pos > 0) ? SubStr(toChars, pos, 1) : ch
    }
    return out
}
