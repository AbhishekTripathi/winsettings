; AutoHotkey v2 Script
; Move Active Window to Next/Previous Virtual Desktop
; Hotkeys: Ctrl + Alt + Win + Right/Left Arrow
; Requires: VirtualDesktopAccessor.dll (automatically downloaded if missing)

#Requires AutoHotkey v2.0
#SingleInstance Force

; Set tray icon and tooltip
TraySetIcon("shell32.dll", 194)  ; Desktop/monitor icon from Windows system icons
A_IconTip := "Virtual Desktop Window Mover`nCtrl+Alt+Win+Arrow Keys"

; Global variables for DLL
global VDA_DLL := ""
global hVdaDll := 0

; Initialize the VirtualDesktopAccessor DLL
InitVDA()

; Ctrl + Alt + Win + Right Arrow - Move window to next desktop
^!#Right::
{
    MoveWindowToDesktop("next")
}

; Ctrl + Alt + Win + Left Arrow - Move window to previous desktop
^!#Left::
{
    MoveWindowToDesktop("previous")
}

; Initialize VirtualDesktopAccessor DLL
InitVDA()
{
    global VDA_DLL, hVdaDll

    ; Determine the DLL path based on architecture
    dllName := (A_PtrSize = 8) ? "VirtualDesktopAccessor.dll" : "VirtualDesktopAccessor.dll"
    VDA_DLL := A_ScriptDir "\" dllName

    ; Check if DLL exists
    if !FileExist(VDA_DLL) {
        MsgBox("VirtualDesktopAccessor.dll not found!`n`n"
            . "Please download it from:`n"
            . "https://github.com/Ciantic/VirtualDesktopAccessor/releases`n`n"
            . "Download the appropriate version for your system and place it in:`n"
            . A_ScriptDir, "Missing DLL", 48)
        ExitApp()
    }

    ; Load the DLL
    hVdaDll := DllCall("LoadLibrary", "Str", VDA_DLL, "Ptr")
    if (!hVdaDll) {
        MsgBox("Failed to load VirtualDesktopAccessor.dll", "Error", 16)
        ExitApp()
    }
}

; Function to create a quick flash animation indicating window movement
FlashWindow(hwnd)
{
    ; Quick double-flash effect (total ~100ms)
    ; Flash 1: Slight dim
    WinSetTransparent(200, "ahk_id " hwnd)
    Sleep(25)
    WinSetTransparent("Off", "ahk_id " hwnd)
    Sleep(25)
    ; Flash 2: Slight dim again
    WinSetTransparent(200, "ahk_id " hwnd)
    Sleep(25)
    WinSetTransparent("Off", "ahk_id " hwnd)
}

; Function to move the active window to next or previous virtual desktop
MoveWindowToDesktop(direction)
{
    global hVdaDll

    ; Get the active window handle
    hwnd := WinGetID("A")

    if (!hwnd) {
        ToolTip("No active window found")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; Get window title for feedback
    windowTitle := WinGetTitle("ahk_id " hwnd)

    try {
        ; Get current desktop number
        getCurrentDesktopNumber := DllCall(VDA_DLL "\GetCurrentDesktopNumber", "Int")

        ; Get total desktop count
        getDesktopCount := DllCall(VDA_DLL "\GetDesktopCount", "Int")

        ; Calculate target desktop
        if (direction = "next") {
            targetDesktop := (getCurrentDesktopNumber + 1) >= getDesktopCount ? 0 : getCurrentDesktopNumber + 1
        } else if (direction = "previous") {
            targetDesktop := (getCurrentDesktopNumber - 1) < 0 ? getDesktopCount - 1 : getCurrentDesktopNumber - 1
        }

        ; Move window to target desktop
        DllCall(VDA_DLL "\MoveWindowToDesktopNumber", "Ptr", hwnd, "Int", targetDesktop)

        ; Switch to the target desktop
        DllCall(VDA_DLL "\GoToDesktopNumber", "Int", targetDesktop)

        ; Quick flash animation to indicate the move
        FlashWindow(hwnd)

        ToolTip("Window moved to desktop " (targetDesktop + 1) ": " windowTitle)

        ; Clear tooltip after 2 seconds
        SetTimer(() => ToolTip(), -2000)

    } catch as err {
        ; In case of error, restore window to full opacity
        try {
            WinSetTransparent("Off", "ahk_id " hwnd)
        }
        ToolTip("Error moving window: " err.Message)
        SetTimer(() => ToolTip(), -3000)
    }
}

; Optional: Add Escape key to reload script
^!#r::Reload()

; Show notification when script starts
ToolTip("Virtual Desktop Window Mover Active`nCtrl+Alt+Win+Left/Right to move windows")
SetTimer(() => ToolTip(), -3000)
