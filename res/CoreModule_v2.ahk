;================= CoreModule v1.0.0 =================
; Core functionality and utilities - provides global variables, configuration,
; logging functions, and application initialization for the Lookup program.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

#Include GuiCore_v2.ahk
coreGui := GuiCore()

#Include ScriptScanner_v2.ahk
scannerScript := ScriptScanner()

; Global variables, constants, and configuration
global objScript := {name: 'AHKHotkeyStringLookup', version: '1.0.0'}
global mapScriptList := Map()
global objGui := {}
global gHotkeyCount := 0
global gHotstringCount := 0
global gScriptCount := 0
global arrayBaseList := []
global myFile := 0    ;; hud

; GUI related global variables (shared across GUI modules)
global g_mainGui := ''       ; Main GUI window
global g_searchEdit := ''    ; Search edit control
global g_searchText := ''    ; The search text value
global g_typeDropDown := ''  ; Type filter dropdown
global g_fileDropDown := ''  ; File filter dropdown
global g_mainListView := ''  ; Main ListView
global g_searchListView := '' ; Search results ListView
global g_contextMenu := ''   ; Context menu for ListView
global g_lvColors := ''      ; LV_Colors instance for ListView row coloring

; NMS Next 6 lines added
DEBUG_ENABLED := IniRead('Lookup.ini', 'Debug', 'DEBUG_ENABLED')
; Declare global color configuration variables (set in main script)
NORMAL_BG_COLOR := IniRead('Lookup.ini', 'ListView', 'NORMAL_BG_COLOR')
NORMAL_TEXT_COLOR := IniRead('Lookup.ini', 'ListView', 'NORMAL_TEXT_COLOR')
CONFLICT_BG_COLOR := IniRead('Lookup.ini', 'ListView', 'CONFLICT_BG_COLOR')
CONFLICT_TEXT_COLOR := IniRead('Lookup.ini', 'ListView', 'CONFLICT_TEXT_COLOR')

logEnabled := IniRead('Lookup.ini', 'Log', 'log')

Class CoreModule {
    ; New : 25-01-24
    ; InitApp : () : Main execution entry point that should be called from main script
    InitApp() {
        ; NMS 1 line added

        this.logToFile('========== CoreModule / InitApp ==========', 'NMS_Start')
        ; Show debug status at startup
        if (DEBUG_ENABLED) {
            MsgBox('Debug mode is enabled.')
            ; Log debug mode status
            this.logToFile('DEBUG MODE ENABLED - Verbose logging active')
            ; Log color configuration in debug mode
            this.logToFile('Color configuration:')
            this.logToFile('  Normal items: BG=0x' . Format('{:06X}', NORMAL_BG_COLOR) . ', Text=0x' . Format('{:06X}', NORMAL_TEXT_COLOR))
            this.logToFile('  Conflicts: BG=0x' . Format('{:06X}', CONFLICT_BG_COLOR) . ', Text=0x' . Format('{:06X}', CONFLICT_TEXT_COLOR))
        } else {
            MsgBox('Debug mode is not enabled.')
            this.logToFile('DEBUG MODE DISABLED - Basic logging only')
        }
        
        this.logToFile('Application startup initiated')
        this.initializeApp()
    }

    ; New : 25-01-24
    ; initializeApp : () : Initialization function - loads scripts and creates the GUI
    initializeApp() {
        ; NMS 1 line added
        this.logToFile('========== CoreModule / initializeApp ==========', 'NMS')
        this.logToFile('========== Application Started ==========')
        this.logToFile('Version: ' objScript.version)

        ; Get list of scripts
        arrayScripts := scannerScript.getRunningScripts()

        arrayScripts := scannerScript.GetNotRunningScripts(arrayScripts)

        if (arrayScripts.Length = 0) {
            this.logToFile('No scripts found. Exiting application.')
            this.logMsgBox(this.GCL(A_ThisFunc, A_LineNumber) 'No scripts were running at this time. Exiting application.', objScript.name, '0x30')
            myFile.close() ;; hud
            ExitApp(0)
        }

        ; Load commands
        scannerScript.loadCommands(arrayScripts)
        ; Debug info only if debug enabled
        if DEBUG_ENABLED {
            debugInfo := 'Debug Info:`n`n'
            debugInfo .= 'Found ' gHotkeyCount ' hotkeys and ' gHotstringCount ' hotstrings in ' gScriptCount ' scripts.`n'
            debugInfo .= 'ArrayBaseList size: ' arrayBaseList.Length '`n`n'

            if (arrayBaseList.Length > 0) {
                debugInfo .= 'First few items in arrayBaseList:`n'
                maxToShow := Min(arrayBaseList.Length, 5)
                Loop maxToShow {
                    i := A_Index
                    item := arrayBaseList[i]
                    source := item.HasOwnProp('source') ? item.source : 'direct code'
                    conflictStatus := ''
                    if (item.HasOwnProp('conflict') && item.conflict && item.conflict.isConflict) {
                        conflictType := item.conflict.HasOwnProp('isExact') && item.conflict.isExact ? 'EXACT' : 'POTENTIAL'
                        conflictStatus := ' [' conflictType ' CONFLICT]'
                    }
                    debugInfo .= i ': ' item.command ' (' (item.type = 'k' ? 'hotkey' : 'hotstring') ') from ' item.file ' [' source ']' conflictStatus '`n'
                }
            } else {
                debugInfo .= 'arrayBaseList is empty! No hotkeys or hotstrings were found.`n`n'
                debugInfo .= 'This might be caused by script detection issues or parsing problems.`n'
                debugInfo .= 'Try running this script with administrator privileges.'
            }

            debugInfo .= '`n`nColor Configuration:`n'
            debugInfo .= 'Normal: BG=0x' . Format('{:06X}', NORMAL_BG_COLOR) . ', Text=0x' . Format('{:06X}', NORMAL_TEXT_COLOR) . '`n'
            debugInfo .= 'Conflict: BG=0x' . Format('{:06X}', CONFLICT_BG_COLOR) . ', Text=0x' . Format('{:06X}', CONFLICT_TEXT_COLOR) . '`n'
            debugInfo .= '`nContinue to display GUI with configurable row coloring.'
            
            this.logToFile(debugInfo)
            this.logMsgBox('CoreModule/initializeApp/124`n`n' debugInfo, objScript.name ' - Debug', '0x40')
        } else {
            ; Basic summary without debug details
            this.logToFile('Scan complete: ' gHotkeyCount ' hotkeys, ' gHotstringCount ' hotstrings, ' arrayBaseList.Length ' total items')
        }

        ; Create GUI
        coreGui.createMainGui()
    }

    ; New : 25-01-24
    ; logToFile : (text, append, debugLevel) : Enhanced logging function with debug levels
    ; text : string - Text to log
    ; append : bool|string - True to append, False to create new, 'NMS'/'NMS_Start' for special logging (optional)
    ; debugLevel : string - Log level: 'INFO', 'DEBUG', 'ERROR' (optional)
    logToFile(text, append := true, debugLevel := 'INFO') {
        static logFile := A_ScriptDir '\AHKHotkeyScanner.log'
        ; NMS Next 3 lines added
        static nmsFile := A_ScriptDir '\NMS_LogFile.log'
        if !logEnabled
            return
        ; Skip debug messages if debug not enabled (except for errors)
        if (!DEBUG_ENABLED && debugLevel = 'DEBUG') {
            return
        }

        ; NMS Next 19 lines added
        if append = 'NMS_Start' {
            FileDelete(nmsFile)
            FileDelete(logFile)
            logText := text
            FileAppend(logText '`n', nmsFile)
            append := true
        } else if append = 'NMS' {
            logText := text
            FileAppend(logText '`n', nmsFile)
            append := true
        } else {

            ; Format the timestamp
            timestamp := FormatTime(A_Now, 'yyyy-MM-dd HH:mm:ss')
            
            ; Add debug level prefix for debug messages
            levelPrefix := DEBUG_ENABLED && debugLevel = 'DEBUG' ? '[DEBUG] ' : ''
            logText := '[' timestamp '] ' levelPrefix text
        }

        if (append) {
            try {
                FileAppend(logText '`n', logFile)
            } catch as err {
                ; If append fails, try creating a new file
                try {
                    ; NMS Next line commented
                    ; FileDelete(logFile)
                    ; NMS next line added
                    Sleep(50)
                    FileAppend(logText '`n', logFile)
                } catch {
                    ; If all fails, try an alternate location
                    try {
                        FileAppend(logText '`n', A_Desktop '\AHKHotkeyScanner.log')
                    } catch {
                        ; Silent fail if we can't log
                    }
                }
            }
        } else {
            try {
                FileDelete(logFile)
                FileAppend('========== ' objScript.name ' v' objScript.version ' Log ==========`n', logFile)
                FileAppend('Started: ' timestamp '`n', logFile)
                if (DEBUG_ENABLED) {
                    FileAppend('DEBUG MODE: ENABLED`n', logFile)
                    FileAppend('COLORS: Normal=0x' . Format('{:06X}', NORMAL_BG_COLOR) . '/0x' . Format('{:06X}', NORMAL_TEXT_COLOR) . 
                            ', Conflict=0x' . Format('{:06X}', CONFLICT_BG_COLOR) . '/0x' . Format('{:06X}', CONFLICT_TEXT_COLOR) . '`n', logFile)
                } else {
                    FileAppend('DEBUG MODE: DISABLED`n', logFile)
                }
                FileAppend(logText '`n', logFile)
            } catch {
                ; Silent fail if we can't log
            }
        }

        ; Also output to debugging console if applicable
        ;~ OutputDebug(logText) ;; hud
    }

    ; New : 25-01-24
    ; logDebug : (text) : Debug-specific logging function - only logs when DEBUG_ENABLED is true
    ; text : string - Debug message to log
    logDebug(text) {
        if (DEBUG_ENABLED) {
            this.logToFile(text, true, 'DEBUG')
        }
    }

    ; New : 25-01-24
    ; logMsgBox : (text, title, options) : Enhanced message box that also logs messages
    ; text : string - Message text to display
    ; title : string - Message box title (optional)
    ; options : string - MsgBox options (e.g., '0x40' for info icon) (optional)
    logMsgBox(text, title := '', options := '0x40') {
        ; Log the message
        this.logToFile('MSGBOX - ' title ': ' text)

        ; Show the message box only if debug enabled or if it's an error
        if (DEBUG_ENABLED || InStr(options, '0x10') || InStr(options, '0x30')) {
            MsgBox(text, title, options)
        }
    }

    ; New : 25-01-24
    ; GCL (funcName, lineNum) : Format function name and line number for logging
    ; funcName : string - Function name
    ; lineNum : int - Line number
    ; Returns : string - Formatted string
    GCL(funcName, lineNum) {
        return Format('{:-30}',funcName) . Format('{:5}',lineNum) . '   '
    }

    ; New : 25-01-24
    ; StrJoin : (arr, delimiter) : Join array elements with delimiter
    ; arr : array - Array of items to join
    ; delimiter : string - Delimiter to use between items (optional)
    ; Returns : string - Joined string
    StrJoin(arr, delimiter := ', ') {
        result := ''
        for i, item in arr {
            if (i > 1)
                result .= delimiter
            result .= item
        }
        return result
    }

    ; New : 25-01-24
    ; HotKeyInClass : () : Setup hotkey for Select All and Copy functionality
    HotKeyInClass() {
        ; NMS 1 line added
        this.logToFile('========== CoreModule / HotkeyInClass ==========', 'NMS')
        HotKey('!a', selectAllAndCopy)

        selectAllAndCopy() {
            MsgBox('Select All and Copy triggered')
            ; Send Ctrl+A to select all
            Send '^a'
            ; Short delay to ensure selection is complete
            Sleep 50
            ; Send Ctrl+C to copy
            Send '^c'
            ; Display notification
            this.logToFile('Hotkey triggered: Ctrl+Alt+A (Select All and Copy)')
        }
    }

    ; New : 25-01-24
    ; myFileDelete : (fileName) : Delete/create new file for logging
    ; fileName : string - File name to delete/create
    myFileDelete(fileName) { ;; hud
        global myFile
        if (myFile = 0) {
            myFile := FileOpen(fileName, 'w')
        }
    }

    ; New : 25-01-24
    ; myFileAppend : (text, fileName) : Append text to file
    ; text : string - Text to append
    ; fileName : string - File name to append to
    myFileAppend(text, fileName) { ;; hud
        global myFile
        if (myFile = 0)
            this.myFileDelete(fileName)
        myFile.write(text)
    }



}
;================= End of CoreModule =================
