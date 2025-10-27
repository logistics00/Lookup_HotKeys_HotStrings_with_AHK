;================= HotkeyLogger v1.0.0 =================
; Enhancement module for AHKHotkeyStringLookup - provides detailed logging
; for script scanning and analysis with enhanced debugging capabilities.

#Requires AutoHotkey v2.0.2+
#SingleInstance

#Include CoreModule_v2.ahk
moduleCore := CoreModule()

Class HotkeyLogger {
    ; This class is designed to enhance the logging capabilities of the AHKHotkeyStringLookup module.
    ; It provides detailed logging for hotkeys and hotstrings discovered in scripts.

    ; Add this to ScriptScanner.ahk to enhance the logging capabilities
    ; This module can be included in ScriptScanner.ahk or CoreModule.ahk

    ; New : 25-01-24
    ; logHotkeyDetails : (scriptName, scriptPath, hotkey, hotstringInfo) : Enhanced logging for hotkey/hotstring discovery
    ; scriptName : string - Name of the script
    ; scriptPath : string - Full path to the script file
    ; hotkey : object - Hotkey information object (optional)
    ; hotstringInfo : object - Hotstring information object (optional)
    logHotkeyDetails(scriptName, scriptPath, hotkey, hotstringInfo) {
        static logFile := A_ScriptDir '\HotkeyDetails.log'

        ; Format the timestamp
        timestamp := FormatTime(A_Now, 'yyyy-MM-dd HH:mm:ss')

        ; Create header if file doesn't exist
        if (!FileExist(logFile)) {
            FileAppend('========== HotkeyDetails Log ==========`n', logFile)
            FileAppend('Started: ' timestamp '`n`n', logFile)
        }

        ; Format the log entry
        logEntry := '[' timestamp '] SCRIPT: ' scriptName '`n'
        logEntry .= '  PATH: ' scriptPath '`n'

        if (IsObject(hotkey)) {
            logEntry .= '  TYPE: Hotkey`n'
            logEntry .= '  LINE: ' hotkey.line '`n'
            logEntry .= '  COMMAND: ' hotkey.command '`n'
            logEntry .= '  CONTENT: ' hotkey.content '`n'
            if (hotkey.HasOwnProp('description') && hotkey.description)
                logEntry .= '  DESCRIPTION: ' hotkey.description '`n'
        }

        if (IsObject(hotstringInfo)) {
            logEntry .= '  TYPE: Hotstring`n'
            logEntry .= '  LINE: ' hotstringInfo.line '`n'
            logEntry .= '  TRIGGER: ' hotstringInfo.trigger '`n'
            logEntry .= '  REPLACEMENT: ' hotstringInfo.replacement '`n'
            logEntry .= '  OPTIONS: ' hotstringInfo.options '`n'
            logEntry .= '  CONTENT: ' hotstringInfo.content '`n'
        }

        logEntry .= '----------------------------------------`n'

        ; Append to log file
        try {
            FileAppend(logEntry, logFile)
        } catch as err {
            ; If append fails, try creating a new file
            try {
                FileDelete(logFile)
                FileAppend('========== HotkeyDetails Log ==========`n', logFile)
                FileAppend('Started: ' timestamp '`n`n', logFile)
                FileAppend(logEntry, logFile)
            } catch {
                ; Silent fail if we can't log
            }
        }
    }

    ; New : 25-01-24
    ; logScriptSummary : (scriptInfo, hotkeyCount, hotstringCount, commandList) : Enhanced script summary logging
    ; scriptInfo : object - Script information object with scriptName and scriptPath
    ; hotkeyCount : int - Number of hotkeys found
    ; hotstringCount : int - Number of hotstrings found
    ; commandList : array - Array of command objects (optional)
    logScriptSummary(scriptInfo, hotkeyCount, hotstringCount, commandList) {
        static logFile := A_ScriptDir '\ScriptSummary.log'

        ; Format the timestamp
        timestamp := FormatTime(A_Now, 'yyyy-MM-dd HH:mm:ss')

        ; Create header if file doesn't exist
        if (!FileExist(logFile)) {
            FileAppend('========== Script Summary Log ==========`n', logFile)
            FileAppend('Started: ' timestamp '`n`n', logFile)
        }

        ; Format the log entry
        logEntry := '[' timestamp '] SCRIPT SUMMARY: ' scriptInfo.scriptName '`n'
        logEntry .= '  PATH: ' scriptInfo.scriptPath '`n'
        logEntry .= '  HOTKEYS: ' hotkeyCount '`n'
        logEntry .= '  HOTSTRINGS: ' hotstringCount '`n'

        if (commandList && commandList.Length > 0) {
            logEntry .= '  COMMANDS:`n'
            for i, cmd in commandList {
                logEntry .= '    ' i '. ' (cmd.type = 'k' ? 'Hotkey: ' : 'Hotstring: ') cmd.command '`n'
                if (i >= 10) {
                    logEntry .= '    (and ' (commandList.Length - 10) ' more...)`n'
                    break
                }
            }
        } else {
            logEntry .= '  COMMANDS: None found`n'
        }

        logEntry .= '----------------------------------------`n'

        ; Append to log file
        try {
            FileAppend(logEntry, logFile)
        } catch as err {
            ; If append fails, try creating a new file
            try {
                FileDelete(logFile)
                FileAppend('========== Script Summary Log ==========`n', logFile)
                FileAppend('Started: ' timestamp '`n`n', logFile)
                FileAppend(logEntry, logFile)
            } catch {
                ; Silent fail if we can't log
            }
        }
    }

    ; New : 25-01-24
    ; analyzeScriptContent : (scriptPath, scriptName) : Analyze script content for statistics and standards compliance
    ; scriptPath : string - Full path to script file
    ; scriptName : string - Name of the script
    ; Returns : object|bool - Analysis results object or false on error
    analyzeScriptContent(scriptPath, scriptName) {
        ; Log that we're analyzing this script
        moduleCore.logToFile('Analyzing content of: ' scriptName)

        try {
            ; Read the script file
            fileContent := FileRead(scriptPath)

            ; Get basic statistics
            ;~ lineCount := StrSplit(fileContent, '`n', '`r').Length
            StrReplace(fileContent, '`n', '`n',, &lineCount) ;; hud
            charCount := StrLen(fileContent)

            ; Check for header format
            hasProperHeader := RegExMatch(fileContent, '^\s*;={10,}\s+\w+\s+v\d+\.\d+\.\d+\s+={10,}')
            hasProperFooter := RegExMatch(fileContent, ';={10,}\s+End of \w+\s+={10,}')

            ; Check for common includes
            hasSingleInstance := InStr(fileContent, '#SingleInstance')
            hasRequiresV2 := InStr(fileContent, '#Requires AutoHotkey v2')

            ; Log the analysis results
            logEntry := '  Script Analysis Results:`n'
            logEntry .= '    Lines: ' lineCount '`n'
            logEntry .= '    Characters: ' charCount '`n'
            logEntry .= '    Has proper header: ' (hasProperHeader ? 'Yes' : 'No') '`n'
            logEntry .= '    Has proper footer: ' (hasProperFooter ? 'Yes' : 'No') '`n'
            logEntry .= '    Has #SingleInstance: ' (hasSingleInstance ? 'Yes' : 'No') '`n'
            logEntry .= '    Has #Requires AHK v2: ' (hasRequiresV2 ? 'Yes' : 'No') '`n'

            moduleCore.logToFile(logEntry)

            return {
                lineCount: lineCount,
                charCount: charCount,
                hasProperHeader: hasProperHeader,
                hasProperFooter: hasProperFooter,
                hasSingleInstance: hasSingleInstance,
                hasRequiresV2: hasRequiresV2
            }
        } catch as err {
            moduleCore.logToFile('  ERROR analyzing script content: ' err.Message)
            return false
        }
    }
}
;================= End of HotkeyLogger =================
