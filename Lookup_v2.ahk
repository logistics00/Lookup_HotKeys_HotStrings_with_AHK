;================= Lookup v1.0.0 =================
; Main script for AHKHotkeyStringLookup - scans running AutoHotkey scripts
; for hotkeys and hotstrings, displays them in a searchable ListView with
; conflict detection against Windows shortcuts and configurable row colors.

#Requires AutoHotkey v2.0.18+
#SingleInstance Force

; ===== DEBUG TOGGLE =====
; Set to true for verbose logging, false for basic logging only
global DEBUG_ENABLED := false

; ===== COLOR CONFIGURATION =====
; RGB color values - change these to customize ListView row colors
; Format: 0xRRGGBB (Red, Green, Blue components)
global NORMAL_BG_COLOR := 0xFFFFFF      ; White background for normal items
global NORMAL_TEXT_COLOR := 0x000000    ; Black text for normal items
global CONFLICT_BG_COLOR := 0xFF0000    ; Red background for conflicts
global CONFLICT_TEXT_COLOR := 0xFFFFFF  ; White text for conflicts

; Color examples for easy reference:
; 0xFFFFFF = White    0x000000 = Black     0xFF0000 = Red      0x00FF00 = Green
; 0x0000FF = Blue     0xFFFF00 = Yellow    0xFF00FF = Magenta  0x00FFFF = Cyan
; 0x808080 = Gray     0xC0C0C0 = Silver    0x800000 = Maroon   0x008000 = Dark Green

; Scripts to skip when scanning - can be filenames or full paths
global arraySkipScriptList := [
    ; Names to skip by pattern match
    "TillaGoto.ahk",                          ; Script for the TillaGoto utility
    "AutoCorrect.ahk",                        ; Common autocorrection script with many hotstrings
    "AHKHotKeyStringLookup.ahk",
    "AHK_v1_test.ahk",
    "AHK_v2_test.ahk",
    'the-Automator Resource Finder.ahk',
    "ToolBar.ahk",                            ; Toolbar utility script

    ; Specific files to skip (exact match paths)
    "S:\Hotstringlookp-ini\Lookup.ahk",
    "C:\Users\Connie Mini PC\OneDrive\Documents\My AHK Scripts\AHKHotkeyStringLookup\AHKHotkeyStringLookup\src\grok.ahk",
    ; "C:\Users\Connie Mini PC\OneDrive\Documents\My AHK Scripts\myhotkeys.ahk",
    "C:\Users\Connie Mini PC\OneDrive\Documents\My AHK Scripts\DesktopMenu\DesktopMenu .ahk",
    "C:\Program Files\Quick Clipboard Editor\QuickClipboardEditor-Receiver.exe",
    "C:\Users\Connie Mini PC\OneDrive\Documents\My AHK Scripts\Schoo.ahk",
    "C:\Users\Connie Mini PC\OneDrive\Documents\My AHK Scripts\OCR with AI 8 Apr 2025\OCR with AI.exe",
    "C:\Users\Connie Mini PC\OneDrive\Documents\My AHK Scripts\GetActivePath\GetActivefilePath.ahk",
    "C:\Program Files\Quick Clipboard Editor\QuickClipboardEditor.exe"
]

; Include modules with debug and color configuration functionality
#Include res\CoreModule_v2.ahk          ; Configuration, globals, and debug support
#Include res\ConflictChecker_v2.ahk     ; Windows shortcut conflict detection
#Include res\GuiListView_v2.ahk         ; ListView management with configurable colors
#Include res\GuiCore_v2.ahk             ; Core GUI creation
#Include res\GuiContextMenu_v2.ahk      ; Context menu functionality
#Include res\ScriptEditor_v2.ahk        ; Script editing functionality
#Include res\GuiSearch_v2.ahk           ; Search functionality with color reapplication
#Include res\WindowsShortcuts_v2.ahk    ; Windows shortcut keys reference
#Include res\ScriptScanner_v2.ahk       ; Script detection and command parsing
#Include res\TriggersIniScanner_v2.ahk  ; Triggers class settings.ini scanner
#Include res\HotkeyLogger_v2.ahk        ; Enhanced logging capabilities
#Include res\IsSkipMatch_v2.ahk         ; Improved skip list functionality
#Include res\Class_LV_Colors_v2.ahk     ; LV_Colors class for row coloring

; Main execution
InitApp()

;================= End of Lookup =================