; ============================================================================
; Mouse Button Volume Control Script
; AutoHotkey v2.0
; ============================================================================
; Description:
;   - XButton2 (Forward): Increases volume
;   - XButton1 (Backward): Decreases volume
;   - Holding the button continuously adjusts volume in increments of 5
;   - Works with any active audio device (built-in or external)
; ============================================================================

#Requires AutoHotkey v2.0

; Set custom tray icon (unique volume/audio icon)
TraySetIcon(A_WinDir . "\System32\mmres.dll", 3)

; ============================================================================
; CONFIGURATION
; ============================================================================

; Volume adjustment settings
global VOLUME_STEP := 5          ; Volume change per adjustment (1-100)
global REPEAT_DELAY := 200       ; Delay in milliseconds between repeats when held

; OSD Display settings
global OSD_WIDTH := 180          ; Width of the OSD window
global OSD_HEIGHT := 50          ; Height of the OSD window
global OSD_POSITION := "bottom"  ; Position: "top", "bottom", "center"
global OSD_OFFSET_Y := 100       ; Distance from top/bottom edge (pixels)

; ============================================================================
; CORE FUNCTIONS
; ============================================================================

/**
 * Adjusts the system volume by a specified amount
 * Uses relative volume adjustment to work with any active device
 * @param step - The amount to change volume (positive to increase, negative to decrease)
 */
AdjustVolume(step) {
    try {
        ; Use relative volume adjustment with the + or - prefix
        ; This works with whichever device is currently active
        if (step > 0) {
            SoundSetVolume("+" . step)
        } else {
            SoundSetVolume(step)  ; step is already negative
        }
        ShowVolumeOSD()
    } catch Error as err {
        ToolTip("Error adjusting volume: " err.Message)
        SetTimer(() => ToolTip(), -2000)
    }
}

/**
 * Displays the current volume level with color-graded visual feedback
 * Gets volume from the currently active default playback device
 */
ShowVolumeOSD() {
    try {
        ; Get volume from default playback device
        currentVolume := Round(SoundGetVolume())

        ; Determine color based on volume level (green -> yellow -> orange -> red)
        if (currentVolume <= 33) {
            barColor := "00D000"      ; Green (low volume)
            bgColor := "003300"       ; Dark green background
        } else if (currentVolume <= 66) {
            barColor := "FFD700"      ; Gold/Yellow (medium volume)
            bgColor := "4D4000"       ; Dark yellow background
        } else if (currentVolume <= 85) {
            barColor := "FF8C00"      ; Orange (high volume)
            bgColor := "4D2A00"       ; Dark orange background
        } else {
            barColor := "FF0000"      ; Red (very high volume)
            bgColor := "4D0000"       ; Dark red background
        }

        ; Create or update the volume OSD GUI
        if (!IsSet(VolumeOSD) || !IsObject(VolumeOSD)) {
            global VolumeOSD := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound", "VolumeOSD")
            VolumeOSD.BackColor := "1a1a1a"
            VolumeOSD.SetFont("s10 w600", "Segoe UI")

            ; Add volume text (smaller padding and size)
            global VolumeText := VolumeOSD.Add("Text", "x10 y5 w" . (OSD_WIDTH - 20) . " c" . barColor . " Center", "")

            ; Add progress bar (smaller height)
            global VolumeBar := VolumeOSD.Add("Progress", "x10 y25 w" . (OSD_WIDTH - 20) . " h20 Background" . bgColor . " c" . barColor, 0)
        }

        ; Update the display
        VolumeText.SetFont("c" . barColor)
        VolumeText.Value := "♪  " . currentVolume . "%  ♪"
        VolumeBar.Opt("Background" . bgColor . " c" . barColor)
        VolumeBar.Value := currentVolume

        ; Calculate position based on configuration
        xPos := (A_ScreenWidth / 2) - (OSD_WIDTH / 2)  ; Always centered horizontally

        if (OSD_POSITION = "top") {
            yPos := OSD_OFFSET_Y
        } else if (OSD_POSITION = "center") {
            yPos := (A_ScreenHeight / 2) - (OSD_HEIGHT / 2)
        } else {  ; default: bottom
            yPos := A_ScreenHeight - OSD_HEIGHT - OSD_OFFSET_Y
        }

        ; Show the OSD at calculated position
        VolumeOSD.Show("w" . OSD_WIDTH . " h" . OSD_HEIGHT . " x" . xPos . " y" . yPos . " NoActivate")

        ; Auto-hide after 1.5 seconds
        SetTimer(() => VolumeOSD.Hide(), -1500)
    } catch {
        ; Fallback if we can't get volume
        ToolTip("Volume adjusted")
        SetTimer(() => ToolTip(), -1000)
    }
}

/**
 * Handles volume adjustment with repeat functionality
 * @param direction - 1 for increase, -1 for decrease
 */
HandleVolumeControl(direction) {
    ; Initial volume adjustment
    AdjustVolume(direction * VOLUME_STEP)

    ; Wait for the repeat delay
    Sleep(REPEAT_DELAY)

    ; Continue adjusting while button is held
    while (GetKeyState(direction > 0 ? "XButton2" : "XButton1", "P")) {
        AdjustVolume(direction * VOLUME_STEP)
        Sleep(REPEAT_DELAY)
    }
}

; ============================================================================
; HOTKEY BINDINGS
; ============================================================================

/**
 * XButton2 (Mouse Forward Button) - Increase Volume
 * Increases volume by VOLUME_STEP units
 * Holding the button continues to increase volume
 */
XButton2:: {
    HandleVolumeControl(1)
}

/**
 * XButton1 (Mouse Backward Button) - Decrease Volume
 * Decreases volume by VOLUME_STEP units
 * Holding the button continues to decrease volume
 */
XButton1:: {
    HandleVolumeControl(-1)
}

; ============================================================================
; SCRIPT INITIALIZATION
; ============================================================================

; Display startup notification
TrayTip("Mouse Volume Control", "Script is running.`nForward: Volume Up`nBackward: Volume Down", 1)

; Auto-execute section ends here
return