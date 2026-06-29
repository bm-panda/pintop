#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

cfgFile := A_ScriptDir "\config.ini"
pinned := Map()
pinTimer := 0
curHotkey := ""

OnExit(Cleanup)

Cleanup(ExitReason, ExitCode) {
    for hwnd, pin in pinned {
        WinSetAlwaysOnTop 0, "ahk_id " hwnd
        try pin.gui.Destroy()
    }
}

LoadHotkey() {
	global curHotkey
	curHotkey := IniRead(cfgFile, "Settings", "Hotkey", "^!Up up")
	if curHotkey
		Hotkey curHotkey, (*) => ToggleTopmost()
}

SetHotkey() {
	global curHotkey
	curHotkey := IniRead(cfgFile, "Settings", "Hotkey", "^!Up up")
	if !curHotkey
		curHotkey := "^!Up up"
	Hotkey curHotkey, (*) => ToggleTopmost()
	Suspend 0
}

tray := A_TrayMenu
tray.Delete()
tray.Add("编辑快捷键(&K)", (*) => ShowHotkeyGui())
tray.Add("恢复默认快捷键(&D)", (*) => ResetHotkey())
tray.Add()
tray.Add("重新加载(&R)", (*) => Reload())
tray.Add()
tray.Add("暂停热键(&H)", (*) => Suspend())
tray.Add("暂停脚本(&P)", (*) => Pause())
tray.Add()
tray.Add("退出(&X)", (*) => ExitApp())
tray.Default := "编辑快捷键(&K)"

ShowHotkeyGui() {
	g := Gui("+AlwaysOnTop", "PinTop - 快捷键设置")
	g.SetFont("s10")
	g.Add("Text",, "按下新的快捷键组合：")
	hkCtrl := g.Add("Hotkey", "w240")
	hkCtrl.Value := SubStr(IniRead(cfgFile, "Settings", "Hotkey", "^!Up up"), 1, -3)
	g.Add("Text", "xs w240", "提示：修改后立即生效")
	g.Add("Button", "Default w80", "保存").OnEvent("Click", SaveHotkey)
	g.Add("Button", "x+10 w80", "取消").OnEvent("Click", (*) => g.Destroy())
	g.OnEvent("Close", (*) => g.Destroy())
	g.Show("w300 h120")

	SaveHotkey(*) {
		val := hkCtrl.Value
		g.Destroy()
		if !val
			return
		IniWrite val " up", cfgFile, "Settings", "Hotkey"
		SetHotkey()
		ShowTip("快捷键已更新")
	}
}

ResetHotkey() {
	IniWrite "^!Up up", cfgFile, "Settings", "Hotkey"
	SetHotkey()
	ShowTip("已恢复默认快捷键 Ctrl+Alt+↑")
}

LoadHotkey()

ToggleTopmost() {
    global pinned, pinTimer
    KeyWait "LWin"
    KeyWait "RWin"
    hwnd := WinExist("A")
    if !hwnd
        return
    class := WinGetClass("ahk_id " hwnd)
    if class ~= "^(Shell_TrayWnd|WorkerW|Progman)$"
        return
    exStyle := WinGetExStyle("ahk_id " hwnd)
    if exStyle & 0x8 {
        WinSetAlwaysOnTop 0, "ahk_id " hwnd
        if pinned.Has(hwnd) {
            pinned[hwnd].Destroy()
            pinned.Delete(hwnd)
        }
        ShowTip("已取消置顶")
    } else {
        WinSetAlwaysOnTop 1, "ahk_id " hwnd
        pin := PinGui(hwnd)
        pinned[hwnd] := pin
        ShowTip("已置顶")
        if !pinTimer
            pinTimer := SetTimer(UpdatePins, 80)
    }
}

class PinGui {
    hwnd := 0
    gui := 0

    __New(targetHwnd) {
        this.hwnd := targetHwnd
        this.gui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20 +E0x08000000")
        this.gui.BackColor := "FFFFFF"
        WinSetTransColor "FFFFFF", this.gui
        this.gui.SetFont("s14", "Segoe UI Symbol")
        this.gui.Add("Text", "cRed x0 y0 BackgroundTrans", "📌")
        this.gui.Show("NA w44 h30")
        this._Reposition()
    }

    _Reposition() {
        mm := WinGetMinMax("ahk_id " this.hwnd)
        if mm = -1 {
            this.gui.Hide()
            return
        }
        WinGetPos &wx, &wy, &ww, &wh, "ahk_id " this.hwnd
        this.gui.Show("NA x" wx + ww / 2 - 22 " y" wy + 2)
    }

    Destroy() {
        try this.gui.Destroy()
    }
}

UpdatePins() {
    global pinned, pinTimer
    dead := []
    if pinned.Count = 0 {
        SetTimer(UpdatePins, 0)
        pinTimer := 0
        return
    }
    for hwnd, pin in pinned {
        if !WinExist("ahk_id " pin.hwnd) {
            dead.Push(hwnd)
            try pin.gui.Destroy()
        } else {
            pin._Reposition()
        }
    }
    for hwnd in dead
        pinned.Delete(hwnd)
}

ShowTip(msg) {
    CoordMode "Mouse", "Screen"
    MouseGetPos &mx, &my
    ToolTip msg, mx + 24, my + 16
    SetTimer () => ToolTip(), -1500
}
