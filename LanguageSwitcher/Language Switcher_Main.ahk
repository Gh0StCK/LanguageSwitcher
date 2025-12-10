#Requires AutoHotkey v2.0+
#Include LanguageSwitcher_UI.ahk   ; подключаем отдельный файл с окном/треем

global ClipSaved := ""
global MyGui      ; GUI создаётся в InitUI() из подключённого файла

; Инициализация GUI и трея
InitUI()

; --- Горячие клавиши ---

; Обычный Pause — с авто-выделением от начала строки
Pause::
{
    Convert(true)   ; true = авто-выделение
}

; Shift + Pause — без авто-выделения (работаем с тем, что уже выделено)
+Pause::
{
    Convert(false)  ; false = не трогаем выделение
}

; --- Основная логика конвертации ---

Convert(autoSelect := true) {
    global ClipSaved
    Critical

    ; 1. Сохраняем текущий буфер обмена
    ClipSaved := ClipboardAll()

    ; 2. При необходимости выделяем текст от начала строки до курсора
    if (autoSelect) {
        Send "+{Home}"
        Sleep 40
    }

    ; 3. Копируем выделенный текст
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.4) {
        RestoreClipboard()
        return
    }

    sel  := A_Clipboard
    conv := ToggleLayout(sel)

    ; Если ничего не изменилось — просто вернуть буфер
    if (conv = sel) {
        RestoreClipboard()
        return
    }

    ; 4. Вставляем сконвертированный текст
    A_Clipboard := conv
    Sleep 40
    Send "^v"

    ; 5. Сменить системную раскладку (Alt+Shift)
    SwitchLayout()

    ; 6. Вернуть исходный буфер через 200 мс
    SetTimer RestoreClipboard, -200
}

RestoreClipboard() {
    global ClipSaved
    if (ClipSaved != "")
        A_Clipboard := ClipSaved
}

; --- Нажатие Alt+Shift для смены языка ---

SwitchLayout() {
    ; если в системе у тебя именно Alt+Shift переключает раскладку
    Send "{LAlt down}{LShift down}{LShift up}{LAlt up}"
}

; --- Конвертация раскладки ---

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
    ; делим строку по символам
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
