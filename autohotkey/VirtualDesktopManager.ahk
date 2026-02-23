; AutoHotkey v2 Script
; Move Active Window to Next/Previous Virtual Desktop & Switch Desktops
; Hotkeys:
;   Ctrl + Alt + Win + Right/Left Arrow  — Move window to next/previous desktop
;   Alt + Win + Right/Left Arrow           — Switch desktop (no window move)
;   Ctrl + Alt + Win + R                   — Reload script
; Requires: VirtualDesktopAccessor.dll

#Requires AutoHotkey v2.0
#SingleInstance Force

; Set tray icon and tooltip
A_IconTip := "Virtual Desktop Manager`nCtrl+Alt+Win+Arrow: Move Window`nAlt+Win+Arrow: Switch Desktop"

; Global variables for DLL
global VDA_DLL := ""
global hVdaDll := 0

; Initialize the VirtualDesktopAccessor DLL
InitVDA()

; Set initial tray icon to current desktop number
try UpdateTrayIcon(DllCall(VDA_DLL "\GetCurrentDesktopNumber", "Int") + 1)
catch
    UpdateTrayIcon(1)

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

; Alt + Win + Right Arrow - Switch to next desktop (no window move)
!#Right::
{
    SwitchDesktop("next")
}

; Alt + Win + Left Arrow - Switch to previous desktop (no window move)
!#Left::
{
    SwitchDesktop("previous")
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

; ─── Dynamic Tray Icon ──────────────────────────────────────────────────────
; Draws the desktop number as the system tray icon.
; Blue badge with white bold number — readable on both light and dark taskbars.
UpdateTrayIcon(number)
{
    static prevIcon := 0
    sz := 16

    ; Create a memory DC
    hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")

    ; Create a 32-bit top-down DIB section
    bmi := Buffer(40, 0)
    NumPut("UInt", 40, bmi, 0)         ; biSize
    NumPut("Int", sz, bmi, 4)          ; biWidth
    NumPut("Int", -sz, bmi, 8)         ; biHeight (negative = top-down)
    NumPut("UShort", 1, bmi, 12)       ; biPlanes
    NumPut("UShort", 32, bmi, 14)      ; biBitCount
    hbm := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bmi, "UInt", 0
        , "Ptr*", &pBits := 0, "Ptr", 0, "UInt", 0, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")

    ; Fill with accent blue background (BGR: 0xD78A00 = RGB(0,138,215))
    hBrush := DllCall("CreateSolidBrush", "UInt", 0xD78A00, "Ptr")
    rc := Buffer(16)
    NumPut("Int", 0, "Int", 0, "Int", sz, "Int", sz, rc)
    DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", hBrush)
    DllCall("DeleteObject", "Ptr", hBrush)

    ; Choose font size: smaller for 2-digit numbers
    fontSize := (number >= 10) ? 11 : 14
    hFont := DllCall("CreateFont"
        , "Int", fontSize     ; nHeight
        , "Int", 0, "Int", 0, "Int", 0
        , "Int", 700          ; fnWeight (bold)
        , "UInt", 0, "UInt", 0, "UInt", 0
        , "UInt", 0           ; charset
        , "UInt", 0, "UInt", 0
        , "UInt", 4            ; ANTIALIASED_QUALITY
        , "UInt", 0
        , "Str", "Segoe UI"
        , "Ptr")
    hFontOld := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")

    ; Draw white number centered
    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)      ; TRANSPARENT
    DllCall("SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)  ; White
    text := String(number)
    DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc
        , "UInt", 0x25)  ; DT_CENTER | DT_VCENTER | DT_SINGLELINE

    DllCall("SelectObject", "Ptr", hdc, "Ptr", hFontOld, "Ptr")
    DllCall("DeleteObject", "Ptr", hFont)

    ; Create mask bitmap (all zeros = fully opaque)
    hbmMask := DllCall("CreateBitmap", "Int", sz, "Int", sz
        , "UInt", 1, "UInt", 1, "Ptr", 0, "Ptr")

    ; Build ICONINFO struct
    ii := Buffer(A_PtrSize = 8 ? 32 : 20, 0)
    NumPut("UInt", 1, ii, 0)                                    ; fIcon = TRUE
    NumPut("Ptr", hbmMask, ii, A_PtrSize = 8 ? 16 : 12)        ; hbmMask
    NumPut("Ptr", hbm, ii, A_PtrSize = 8 ? 24 : 16)            ; hbmColor
    hIcon := DllCall("CreateIconIndirect", "Ptr", ii, "Ptr")

    ; Cleanup GDI objects
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hbmOld, "Ptr")
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteObject", "Ptr", hbmMask)
    DllCall("DeleteDC", "Ptr", hdc)

    ; Set as tray icon
    try TraySetIcon("HICON:" hIcon)

    ; Destroy the previous icon (AHK copies it internally)
    if (prevIcon)
        DllCall("DestroyIcon", "Ptr", prevIcon)
    prevIcon := hIcon
}

; ─── Balloon Toast Notification ──────────────────────────────────────────────
; Shows a compact XP-style balloon popup just above the system tray.
; Light background, dark text, rounded corners, auto-dismisses after `duration` ms.
; Consecutive calls replace the previous balloon.
ShowToast(text, duration := 2000)
{
    static toast := ""
    static destroyTimer := ""

    ; Destroy any existing balloon
    if (toast) {
        try toast.Destroy()
        toast := ""
    }
    if (destroyTimer) {
        SetTimer(destroyTimer, 0)
        destroyTimer := ""
    }

    ; --- Build the balloon GUI ---
    toast := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    toast.BackColor := "FFFEF5"          ; warm cream white (classic balloon feel)
    toast.MarginX := 16
    toast.MarginY := 12

    ; Title line — bold, dark
    toast.SetFont("s9 Bold c333333", "Segoe UI")
    toast.Add("Text", "x16 y10", "🖥 Virtual Desktop")

    ; Separator line
    toast.Add("Progress", "x12 y+4 w260 h1 BackgroundCCCCCC cCCCCCC Range0-100", 100)

    ; Body text — regular weight, fixed width for wrapping
    toast.SetFont("s9 Norm c444444", "Segoe UI")
    toast.Add("Text", "x16 y+6 w250 r5", text)

    ; Show once to calculate auto-size dimensions
    toast.Show("NoActivate AutoSize")
    toast.GetPos(,, &toastW, &toastH)

    ; Rounded corners — classic balloon shape
    try WinSetRegion("0-0 W" toastW " H" toastH " R8-8", toast)

    ; Position: just above the taskbar, near the system tray (bottom-right)
    xPos := A_ScreenWidth - toastW - 12
    yPos := A_ScreenHeight - toastH - 52
    toast.Show("NoActivate x" xPos " y" yPos)

    ; Auto-destroy after duration
    destroyTimer := ObjBindMethod(toast, "Destroy")
    SetTimer(destroyTimer, -duration)
}

; ─── Flash Animation ─────────────────────────────────────────────────────────
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

; ─── Check if a Window is Movable ────────────────────────────────────────────
; Returns true if the HWND belongs to the desktop shell or taskbar (not movable).
IsDesktopOrShell(hwnd)
{
    try {
        winClass := WinGetClass("ahk_id " hwnd)
        if (winClass = "Progman" || winClass = "WorkerW" || winClass = "Shell_TrayWnd" || winClass = "Shell_SecondaryTrayWnd")
            return true
    }
    return false
}

; ─── Move Window to Desktop ──────────────────────────────────────────────────
; Function to move the active window to next or previous virtual desktop
MoveWindowToDesktop(direction)
{
    global hVdaDll

    ; Get the active window handle
    hwnd := WinGetID("A")

    ; Check if there's no real window selected
    if (!hwnd || IsDesktopOrShell(hwnd)) {
        ShowToast("No window selected`nClick a window first, then try again", 2500)
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

        ; Truncate long titles
        if (StrLen(windowTitle) > 40)
            windowTitle := SubStr(windowTitle, 1, 37) "..."

        ShowToast("Moved to Desktop " (targetDesktop + 1) "`n" windowTitle)

        ; Update tray icon to reflect new desktop
        UpdateTrayIcon(targetDesktop + 1)

    } catch as err {
        ; In case of error, restore window to full opacity
        try {
            WinSetTransparent("Off", "ahk_id " hwnd)
        }
        ShowToast("Error moving window`n" err.Message, 3000)
    }
}

; ─── Switch Desktop (No Window Move) ─────────────────────────────────────────
; Switches to the next or previous virtual desktop without moving any window.
; Does NOT wrap around — stops at the first and last desktop.
SwitchDesktop(direction)
{
    global hVdaDll

    try {
        ; Get current desktop number
        currentDesktop := DllCall(VDA_DLL "\GetCurrentDesktopNumber", "Int")

        ; Get total desktop count
        desktopCount := DllCall(VDA_DLL "\GetDesktopCount", "Int")

        ; Calculate target desktop (no wrap-around)
        if (direction = "next") {
            if (currentDesktop + 1 >= desktopCount) {
                ShowToast("Already on Desktop " desktopCount " (last)")
                return
            }
            targetDesktop := currentDesktop + 1
        } else if (direction = "previous") {
            if (currentDesktop <= 0) {
                ShowToast("Already on Desktop 1 (first)")
                return
            }
            targetDesktop := currentDesktop - 1
        }

        ; Switch to the target desktop
        DllCall(VDA_DLL "\GoToDesktopNumber", "Int", targetDesktop)

        ShowToast("Switched to Desktop " (targetDesktop + 1) " of " desktopCount)

        ; Update tray icon to reflect new desktop
        UpdateTrayIcon(targetDesktop + 1)

    } catch as err {
        ShowToast("Error switching desktop`n" err.Message, 3000)
    }
}

; Optional: Ctrl+Alt+Win+R to reload script
^!#r::Reload()

; Show notification when script starts
ShowToast("Ctrl+Alt+Win+Arrow : Move Window`nAlt+Win+Arrow : Switch Desktop", 3000)
