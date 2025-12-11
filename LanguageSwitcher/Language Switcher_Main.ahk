#Requires AutoHotkey v2.0+
#Include LanguageSwitcher_UI.ahk

global ClipSaved := ""
global MyGui

InitUI()

Pause::
{
    Convert(true)
}

+Pause::
{
    Convert(false)
}

^CtrlBreak::
{
    Send "^+{Left}"
    Sleep 40
    Convert(false)
}

Convert(autoSelect := true) {
    global ClipSaved
    Critical

    ClipSaved := ClipboardAll()

    if (autoSelect) {
        Send "+{Home}"
        Sleep 40
    }

    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.4) {
        RestoreClipboard()
        return
    }

    sel  := A_Clipboard
    conv := ToggleLayout(sel)

    if (conv = sel) {
        RestoreClipboard()
        return
    }

    A_Clipboard := conv
    Sleep 40
    Send "^v"

    SwitchLayout()

    SetTimer RestoreClipboard, -200
}

RestoreClipboard() {
    global ClipSaved
    if (ClipSaved != "")
        A_Clipboard := ClipSaved
}

SwitchLayout() {
    Send "{LAlt down}{LShift down}{LShift up}{LAlt up}"
}

ToggleLayout(str) {
    if RegExMatch(str, "[А-Яа-яЁё]")
        return RuToEn(str)
    else if RegExMatch(str, "[A-Za-z]")
        return EnToRu(str)
    return str
}

RuToEn(str) {
    ru := "ёйцукенгшщзхъфывапролджэячсмитьбю"
        . "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ"
    en := "`~qwertyuiop[]asdfghjkl;'zxcvbnm,./"
        . "QWERTYUIOP{}ASDFGHJKL:" . Chr(34) . "ZXCVBNM<>"
    return MapLayout(str, ru, en)
}

EnToRu(str) {
    ru := "ёйцукенгшщзхъфывапролджэячсмитьбю"
        . "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ"
    en := "`~qwertyuiop[]asdfghjkl;'zxcvbnm,./"
        . "QWERTYUIOP{}ASDFGHJKL:" . Chr(34) . "ZXCVBNM<>"
    return MapLayout(str, en, ru)
}

MapLayout(str, from, to) {
    out := ""
    for _, ch in StrSplit(str, "")
    {
        pos := InStr(from, ch)
        if (pos > 0)
            out .= SubStr(to, pos, 1)
        else
            out .= ch
    }
    return out
}