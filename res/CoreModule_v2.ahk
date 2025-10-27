;================= CoreModule v1.0.0 =================
; Core functionality and utilities - provides global variables, configuration,
; logging functions, and application initialization for the Lookup program.

#Requires AutoHotkey v2.0.2+

; Global variables, constants, and configuration
global objScript := {name: "AHKHotkeyStringLookup", version: "1.0.0"}
global mapScriptList := Map()
global objGui := {}
global gHotkeyCount := 0
global gHotstringCount := 0
global gScriptCount := 0
global arrayBaseList := []

; GUI related global variables (shared across GUI modules)
global g_mainGui := ""       ; Main GUI window
global g_searchEdit := ""    ; Search edit control
global g_searchText := ""    ; The search text value
global g_typeDropDown := ""  ; Type filter dropdown
global g_fileDropDown := ""  ; File filter dropdown
global g_mainListView := ""  ; Main ListView
global g_searchListView := "" ; Search results ListView
global g_contextMenu := ""   ; Context menu for ListView
global g_lvColors := ""      ; LV_Colors instance for ListView row coloring

; Main execution entry point that should be called from main script
InitApp() {
    ; Show debug status at startup
    if (DEBUG_ENABLED) {
        logToFile("DEBUG MODE ENABLED - Verbose logging active")
        ; Log color configuration in debug mode
        logToFile("Color configuration:")
        logToFile("  Normal items: BG=0x" . Format("{:06X}", NORMAL_BG_COLOR) . ", Text=0x" . Format("{:06X}", NORMAL_TEXT_COLOR))
        logToFile("  Conflicts: BG=0x" . Format("{:06X}", CONFLICT_BG_COLOR) . ", Text=0x" . Format("{:06X}", CONFLICT_TEXT_COLOR))
    } else {
        logToFile("DEBUG MODE DISABLED - Basic logging only")
    }
    
    logToFile("Application startup initiated")
    initializeApp()
}

; Initialization function - loads scripts and creates the GUI
initializeApp() {
    logToFile("========== Application Started ==========", false)
    logToFile("Version: " objScript.version)

    ; Get list of scripts
    arrayScripts := getRunningScripts()

    if (arrayScripts.Length = 0) {
        logToFile("No scripts found. Exiting application.")
        logMsgBox("No scripts were running at this time. Exiting application.", objScript.name, "0x30")
        ExitApp(0)
    }

    ; Load commands
    loadCommands(arrayScripts)

    ; Debug info only if debug enabled
    if (DEBUG_ENABLED) {
        debugInfo := "Debug Info:`n`n"
        debugInfo .= "Found " gHotkeyCount " hotkeys and " gHotstringCount " hotstrings in " gScriptCount " scripts.`n"
        debugInfo .= "ArrayBaseList size: " arrayBaseList.Length "`n`n"

        if (arrayBaseList.Length > 0) {
            debugInfo .= "First few items in arrayBaseList:`n"
            maxToShow := Min(arrayBaseList.Length, 5)
            Loop maxToShow {
                i := A_Index
                item := arrayBaseList[i]
                source := item.HasOwnProp("source") ? item.source : "direct code"
                conflictStatus := ""
                if (item.HasOwnProp("conflict") && item.conflict && item.conflict.isConflict) {
                    conflictType := item.conflict.HasOwnProp("isExact") && item.conflict.isExact ? "EXACT" : "POTENTIAL"
                    conflictStatus := " [" conflictType " CONFLICT]"
                }
                debugInfo .= i ": " item.command " (" (item.type = "k" ? "hotkey" : "hotstring") ") from " item.file " [" source "]" conflictStatus "`n"
            }
        } else {
            debugInfo .= "arrayBaseList is empty! No hotkeys or hotstrings were found.`n`n"
            debugInfo .= "This might be caused by script detection issues or parsing problems.`n"
            debugInfo .= "Try running this script with administrator privileges."
        }

        debugInfo .= "`n`nColor Configuration:`n"
        debugInfo .= "Normal: BG=0x" . Format("{:06X}", NORMAL_BG_COLOR) . ", Text=0x" . Format("{:06X}", NORMAL_TEXT_COLOR) . "`n"
        debugInfo .= "Conflict: BG=0x" . Format("{:06X}", CONFLICT_BG_COLOR) . ", Text=0x" . Format("{:06X}", CONFLICT_TEXT_COLOR) . "`n"
        debugInfo .= "`nContinue to display GUI with configurable row coloring."
        
        logToFile(debugInfo)
        logMsgBox(debugInfo, objScript.name " - Debug", "T10 0x40")
    } else {
        ; Basic summary without debug details
        logToFile("Scan complete: " gHotkeyCount " hotkeys, " gHotstringCount " hotstrings, " arrayBaseList.Length " total items")
    }

    ; Create GUI
    createMainGui()
}

; Enhanced logging function with debug levels
logToFile(text, append := true, debugLevel := "INFO") {
    static logFile := A_ScriptDir "\AHKHotkeyScanner.log"

    ; Skip debug messages if debug not enabled (except for errors)
    if (!DEBUG_ENABLED && debugLevel = "DEBUG") {
        return
    }

    ; Format the timestamp
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    
    ; Add debug level prefix for debug messages
    levelPrefix := DEBUG_ENABLED && debugLevel = "DEBUG" ? "[DEBUG] " : ""
    logText := "[" timestamp "] " levelPrefix text

    if (append) {
        try {
            FileAppend(logText "`n", logFile)
        } catch as err {
            ; If append fails, try creating a new file
            try {
                FileDelete(logFile)
                FileAppend(logText "`n", logFile)
            } catch {
                ; If all fails, try an alternate location
                try {
                    FileAppend(logText "`n", A_Desktop "\AHKHotkeyScanner.log")
                } catch {
                    ; Silent fail if we can't log
                }
            }
        }
    } else {
        try {
            FileDelete(logFile)
            FileAppend("========== " objScript.name " v" objScript.version " Log ==========`n", logFile)
            FileAppend("Started: " timestamp "`n", logFile)
            if (DEBUG_ENABLED) {
                FileAppend("DEBUG MODE: ENABLED`n", logFile)
                FileAppend("COLORS: Normal=0x" . Format("{:06X}", NORMAL_BG_COLOR) . "/0x" . Format("{:06X}", NORMAL_TEXT_COLOR) . 
                          ", Conflict=0x" . Format("{:06X}", CONFLICT_BG_COLOR) . "/0x" . Format("{:06X}", CONFLICT_TEXT_COLOR) . "`n", logFile)
            } else {
                FileAppend("DEBUG MODE: DISABLED`n", logFile)
            }
            FileAppend(logText "`n", logFile)
        } catch {
            ; Silent fail if we can't log
        }
    }

    ; Also output to debugging console if applicable
    OutputDebug(logText)
}

; Debug-specific logging function - only logs when DEBUG_ENABLED is true
logDebug(text) {
    if (DEBUG_ENABLED) {
        logToFile(text, true, "DEBUG")
    }
}

; Enhanced message box that also logs messages
logMsgBox(text, title := "", options := "0x40") {
    ; Log the message
    logToFile("MSGBOX - " title ": " text)

    ; Show the message box only if debug enabled or if it's an error
    if (DEBUG_ENABLED || InStr(options, "0x10") || InStr(options, "0x30")) {
        MsgBox(text, title, options)
    }
}

; Array/string utilities
StrJoin(arr, delimiter := ", ") {
    result := ""
    for i, item in arr {
        if (i > 1)
            result .= delimiter
        result .= item
    }
    return result
}

; Hotkey: Ctrl+Alt+A - Select All and Copy
^!a::selectAllAndCopy()

; Function to perform Select All and Copy using Windows shortcuts
selectAllAndCopy() {
    ; Send Ctrl+A to select all
    Send "^a"
    ; Short delay to ensure selection is complete
    Sleep 50
    ; Send Ctrl+C to copy
    Send "^c"
    ; Display notification
    logToFile("Hotkey triggered: Ctrl+Alt+A (Select All and Copy)")
}

;================= End of CoreModule =================