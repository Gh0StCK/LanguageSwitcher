; Файл UI. Подключается из LanguageSwitcher_Main.ahk через:
; #Include LanguageSwitcher_UI.ahk
; и вызов InitUI()

InitUI() {
    global MyGui, gChkAutoMinimize, gAutoMinimize

    ; --- читаем настройку авто-сворачивания из INI ---
    iniFile := A_ScriptDir "\LanguageSwitcher.ini"
    val := IniRead(iniFile, "General", "AutoMinimize", "1")  ; по умолчанию: 1 = сворачивать
    gAutoMinimize := (val = "1")

    ; --- создаём окно ---
    MyGui := Gui(, "Language Switcher")
    ; Всегда сверху, нормальный заголовок, есть крестик и кнопка свернуть
    MyGui.Opt("+AlwaysOnTop +MinimizeBox +SysMenu")

    ; Крупный шрифт для подписи
    MyGui.SetFont("s16 Bold", "Segoe UI")
    MyGui.Add("Text", "x0 y0 w260 Center", "Made by Gh0StCK`n    v0.7.0")

    ; Чуть меньший шрифт для настройки
    MyGui.SetFont("s10", "Segoe UI")
    gChkAutoMinimize := MyGui.Add(
        "CheckBox"
      , "x10 y+10 w240"
      , "Сворачивать в трей при запуске"
    )
    gChkAutoMinimize.Value := gAutoMinimize ? 1 : 0
    gChkAutoMinimize.OnEvent("Click", AutoMinimize_Changed)

    ; события окна: крестик
    MyGui.OnEvent("Close", Gui_Close)

    ; --- показываем или сразу прячем окно при запуске ---

    if gAutoMinimize {
        ; Инициализировать, но сразу спрятать
        MyGui.Show("w260 h130 Hide")
    } else {
        MyGui.Show("w260 h130 Center")
    }

    ; --- Меню трея ---

    A_TrayMenu.Delete()                          ; очистить стандартное меню
    A_TrayMenu.Add("Открыть окно", Tray_Open)
    A_TrayMenu.Add("Выход",        Tray_Exit)
    A_TrayMenu.Default    := "Открыть окно"      ; действие по умолчанию
    A_TrayMenu.ClickCount := 2                   ; двойной клик = открыть окно

    ; --- Ловим системные команды (минимизация и т.п.) ---
    OnMessage(0x0112, WM_SYSCOMMAND)  ; WM_SYSCOMMAND
}

; --- обработчики GUI ---

Gui_Close(thisGui) {
    ; Нажали крестик — полностью выходим
    ExitApp
}

; --- обработчики трея ---

Tray_Open(*) {
    global MyGui
    if !IsSet(MyGui)
        return
    MyGui.Show("w260 h130 Center")
}

Tray_Exit(*) {
    ExitApp
}

; --- обработчик изменения чекбокса ---

AutoMinimize_Changed(ctrl, *) {
    global gAutoMinimize
    gAutoMinimize := (ctrl.Value = 1)

    iniFile := A_ScriptDir "\LanguageSwitcher.ini"
    IniWrite(gAutoMinimize ? "1" : "0", iniFile, "General", "AutoMinimize")
}

; --- перехват системной команды "Свернуть" ---

WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
    global MyGui

    ; 0xF020 = SC_MINIMIZE
    if (wParam = 0xF020) && IsSet(MyGui) && (hwnd = MyGui.Hwnd) {
        MyGui.Hide()  ; прячем окно, иконка остаётся в трее
        return 0      ; говорим Windows "мы обработали"
    }

    ; остальное не трогаем → вернётся стандартное поведение
}
