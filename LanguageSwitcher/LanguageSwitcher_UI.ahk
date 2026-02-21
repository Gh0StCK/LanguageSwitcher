; LanguageSwitcher_UI.ahk
; Подключается из LanguageSwitcher_Main.ahk через:
;   #Include LanguageSwitcher_UI.ahk
; и вызов InitUI()

; =========================
; КОНСТАНТЫ / INI ХЕЛПЕРЫ
; =========================
global LS_INI_FILE := A_ScriptDir "\LanguageSwitcher.ini"
global LS_INI_SECTION := "General"

IniReadBool(key, default := true) {
    global LS_INI_FILE, LS_INI_SECTION
    val := IniRead(LS_INI_FILE, LS_INI_SECTION, key, default ? "1" : "0")
    return (val = "1")
}

IniWriteBool(key, value) {
    global LS_INI_FILE, LS_INI_SECTION
    IniWrite(value ? "1" : "0", LS_INI_FILE, LS_INI_SECTION, key)
}

; =========================
; UI
; =========================
InitUI() {
    global MyGui
    global gChkAutoMinimize, gAutoMinimize
    global gChkSwitchShift, gChkSwitchCtrl
    global gSwitchAfterShiftBreak, gSwitchAfterCtrlBreak

    ; --- читаем настройки из INI ---
    gAutoMinimize          := IniReadBool("AutoMinimize", true)
    gSwitchAfterShiftBreak := IniReadBool("SwitchAfterShiftBreak", true)
    gSwitchAfterCtrlBreak  := IniReadBool("SwitchAfterCtrlBreak", true)

    try Log("UI read INI | AutoMin=" (gAutoMinimize?1:0)
        " ShiftSwitch=" (gSwitchAfterShiftBreak?1:0)
        " CtrlSwitch=" (gSwitchAfterCtrlBreak?1:0))

    ; --- создаём окно ---
    MyGui := Gui(, "Language Switcher")
    MyGui.Opt("+AlwaysOnTop +MinimizeBox +SysMenu")

    MyGui.SetFont("s16 Bold", "Segoe UI")
    MyGui.Add("Text", "x0 y0 w300 Center", "Made by Gh0StCK`n    v0.8.1")

    MyGui.SetFont("s10", "Segoe UI")

    gChkAutoMinimize := MyGui.Add("CheckBox", "x10 y+10 w280", "Сворачивать в трей при запуске")
    gChkAutoMinimize.Value := gAutoMinimize ? 1 : 0
    gChkAutoMinimize.OnEvent("Click", AutoMinimize_Changed)

    gChkSwitchShift := MyGui.Add("CheckBox", "x10 y+8 w280", "Переключать раскладку после Shift+Break")
    gChkSwitchShift.Value := gSwitchAfterShiftBreak ? 1 : 0
    gChkSwitchShift.OnEvent("Click", SwitchShift_Changed)

    gChkSwitchCtrl := MyGui.Add("CheckBox", "x10 y+6 w280", "Переключать раскладку после Ctrl+Break")
    gChkSwitchCtrl.Value := gSwitchAfterCtrlBreak ? 1 : 0
    gChkSwitchCtrl.OnEvent("Click", SwitchCtrl_Changed)

    MyGui.OnEvent("Close", Gui_Close)

    if gAutoMinimize
        MyGui.Show("w300 h190 Hide")
    else
        MyGui.Show("w300 h190 Center")

    ; --- Меню трея ---
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Открыть окно", Tray_Open)
    A_TrayMenu.Add("Выход",        Tray_Exit)
    A_TrayMenu.Default    := "Открыть окно"
    A_TrayMenu.ClickCount := 2

    OnMessage(0x0112, WM_SYSCOMMAND)
}

; --- handlers ---
Gui_Close(thisGui) {
    ExitApp
}

Tray_Open(*) {
    global MyGui
    if !IsSet(MyGui)
        return
    MyGui.Show("w300 h190 Center")
}

Tray_Exit(*) {
    ExitApp
}

AutoMinimize_Changed(ctrl, *) {
    global gAutoMinimize
    gAutoMinimize := (ctrl.Value = 1)
    IniWriteBool("AutoMinimize", gAutoMinimize)
    try Log("UI AutoMinimize changed -> " (gAutoMinimize?1:0))
}

SwitchShift_Changed(ctrl, *) {
    global gSwitchAfterShiftBreak
    gSwitchAfterShiftBreak := (ctrl.Value = 1)
    IniWriteBool("SwitchAfterShiftBreak", gSwitchAfterShiftBreak)
    try Log("UI SwitchAfterShiftBreak changed -> " (gSwitchAfterShiftBreak?1:0))
}

SwitchCtrl_Changed(ctrl, *) {
    global gSwitchAfterCtrlBreak
    gSwitchAfterCtrlBreak := (ctrl.Value = 1)
    IniWriteBool("SwitchAfterCtrlBreak", gSwitchAfterCtrlBreak)
    try Log("UI SwitchAfterCtrlBreak changed -> " (gSwitchAfterCtrlBreak?1:0))
}

WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
    global MyGui
    if (wParam = 0xF020) && IsSet(MyGui) && (hwnd = MyGui.Hwnd) {
        MyGui.Hide()
        try Log("UI minimized -> hide to tray")
        return 0
    }
}