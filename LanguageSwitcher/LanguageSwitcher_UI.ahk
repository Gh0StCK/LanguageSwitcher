; LanguageSwitcher_UI.ahk
; Подключается из LanguageSwitcher_Main.ahk через:
;   #Include LanguageSwitcher_UI.ahk
; и вызов InitUI()

; =========================
; КОНСТАНТЫ / INI ХЕЛПЕРЫ
; =========================
global LS_INI_FILE := A_ScriptDir "\LanguageSwitcher.ini"
global LS_INI_SECTION := "General"
global LS_UI_WIDTH := 300
global LS_UI_HEIGHT := 210

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
    global gChkSwitchBreak, gChkSwitchShift, gChkSwitchCtrl
    global gSwitchAfterBreak, gSwitchAfterShiftBreak, gSwitchAfterCtrlBreak

    ; --- читаем настройки из INI ---
    gAutoMinimize          := IniReadBool("AutoMinimize", true)
    gSwitchAfterBreak      := IniReadBool("SwitchAfterBreak", true)
    gSwitchAfterShiftBreak := IniReadBool("SwitchAfterShiftBreak", true)
    gSwitchAfterCtrlBreak  := IniReadBool("SwitchAfterCtrlBreak", true)

    try Log("UI read INI | AutoMin=" (gAutoMinimize?1:0)
        " BreakSwitch=" (gSwitchAfterBreak?1:0)
        " ShiftSwitch=" (gSwitchAfterShiftBreak?1:0)
        " CtrlSwitch=" (gSwitchAfterCtrlBreak?1:0))

    ; --- создаём окно ---
    MyGui := Gui(, "Language Switcher")
    MyGui.Opt("+AlwaysOnTop +MinimizeBox +SysMenu")

    MyGui.SetFont("s16 Bold", "Segoe UI")
    MyGui.Add("Text", "x0 y0 w300 Center", "Made by Gh0StCK`n    v0.8.1")

    MyGui.SetFont("s10", "Segoe UI")

    gChkAutoMinimize := AddSettingCheckbox(MyGui, "x10 y+10 w280", "Сворачивать в трей при запуске", gAutoMinimize, AutoMinimize_Changed)
    gChkSwitchBreak := AddSettingCheckbox(MyGui, "x10 y+8 w280", "Переключать раскладку после Break", gSwitchAfterBreak, SwitchBreak_Changed)
    gChkSwitchShift := AddSettingCheckbox(MyGui, "x10 y+8 w280", "Переключать раскладку после Shift+Break", gSwitchAfterShiftBreak, SwitchShift_Changed)
    gChkSwitchCtrl := AddSettingCheckbox(MyGui, "x10 y+6 w280", "Переключать раскладку после Ctrl+Break", gSwitchAfterCtrlBreak, SwitchCtrl_Changed)

    MyGui.OnEvent("Close", Gui_Close)

    if gAutoMinimize
        ShowMainWindow("Hide")
    else
        ShowMainWindow("Center")

    ; --- Меню трея ---
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Открыть окно", Tray_Open)
    A_TrayMenu.Add("Выход",        Tray_Exit)
    A_TrayMenu.Default    := "Открыть окно"
    A_TrayMenu.ClickCount := 2

    OnMessage(0x0112, WM_SYSCOMMAND)
}

AddSettingCheckbox(guiObj, options, text, currentValue, onClickHandler) {
    ctrl := guiObj.Add("CheckBox", options, text)
    ctrl.Value := currentValue ? 1 : 0
    ctrl.OnEvent("Click", onClickHandler)
    return ctrl
}

ShowMainWindow(extraOptions := "Center") {
    global MyGui, LS_UI_WIDTH, LS_UI_HEIGHT
    if !IsSet(MyGui)
        return
    MyGui.Show("w" LS_UI_WIDTH " h" LS_UI_HEIGHT " " extraOptions)
}

; --- handlers ---
Gui_Close(thisGui) {
    ExitApp
}

Tray_Open(*) {
    ShowMainWindow("Center")
}

Tray_Exit(*) {
    ExitApp
}

AutoMinimize_Changed(ctrl, *) {
    global gAutoMinimize
    UpdateBoolSetting(&gAutoMinimize, "AutoMinimize", ctrl.Value = 1, "UI AutoMinimize")
}

SwitchBreak_Changed(ctrl, *) {
    global gSwitchAfterBreak
    UpdateBoolSetting(&gSwitchAfterBreak, "SwitchAfterBreak", ctrl.Value = 1, "UI SwitchAfterBreak")
}

SwitchShift_Changed(ctrl, *) {
    global gSwitchAfterShiftBreak
    UpdateBoolSetting(&gSwitchAfterShiftBreak, "SwitchAfterShiftBreak", ctrl.Value = 1, "UI SwitchAfterShiftBreak")
}

SwitchCtrl_Changed(ctrl, *) {
    global gSwitchAfterCtrlBreak
    UpdateBoolSetting(&gSwitchAfterCtrlBreak, "SwitchAfterCtrlBreak", ctrl.Value = 1, "UI SwitchAfterCtrlBreak")
}

UpdateBoolSetting(&settingVar, iniKey, value, logPrefix) {
    settingVar := value
    IniWriteBool(iniKey, settingVar)
    try Log(logPrefix " changed -> " (settingVar ? 1 : 0))
}

WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
    global MyGui
    if (wParam = 0xF020) && IsSet(MyGui) && (hwnd = MyGui.Hwnd) {
        MyGui.Hide()
        try Log("UI minimized -> hide to tray")
        return 0
    }
}
