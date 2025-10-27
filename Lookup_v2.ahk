;================= Lookup v1.0.0 =================
; Main script for AHKHotkeyStringLookup - scans running AutoHotkey scripts
; for hotkeys and hotstrings, displays them in a searchable ListView with
; conflict detection against Windows shortcuts and configurable row colors.

#Requires AutoHotkey v2.0.18+
#SingleInstance Force
#Include .\res\CoreModule_v2.ahk      ; Configuration, globals, and debug support

moduleCore := CoreModule()

; New : 25-01-24
; Main entry point - initializes the application
moduleCore.InitApp()
;================= End of Lookup =================
