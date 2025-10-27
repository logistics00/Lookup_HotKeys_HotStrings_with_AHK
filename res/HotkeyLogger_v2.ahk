;================= HotkeyLogger v1.0.0 =================
; Enhancement module for AHKHotkeyStringLookup - provides detailed logging
; for script scanning and analysis with enhanced debugging capabilities.

#Requires AutoHotkey v2.0.2+
#SingleInstance

; Add this to ScriptScanner.ahk to enhance the logging capabilities
; This module can be included in ScriptScanner.ahk or CoreModule.ahk

; Enhanced logging for hotkey/hotstring discovery
logHotkeyDetails(scriptName, scriptPath, hotkey, hotstringInfo) {
    static logFile := A_ScriptDir "\HotkeyDetails.log"

    ; Format the timestamp
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    ; Create header if file doesn't exist
    if (!FileExist(logFile)) {
        FileAppend("========== HotkeyDetails Log ==========`n", logFile)
        FileAppend("Started: " timestamp "`n`n", logFile)
    }

    ; Format the log entry
    logEntry := "[" timestamp "] SCRIPT: " scriptName "`n"
    logEntry .= "  PATH: " scriptPath "`n"

    if (IsObject(hotkey)) {
        logEntry .= "  TYPE: Hotkey`n"
        logEntry .= "  LINE: " hotkey.line "`n"
        logEntry .= "  COMMAND: " hotkey.command "`n"
        logEntry .= "  CONTENT: " hotkey.content "`n"
        if (hotkey.HasOwnProp("description") && hotkey.description)
            logEntry .= "  DESCRIPTION: " hotkey.description "`n"
    }

    if (IsObject(hotstringInfo)) {
        logEntry .= "  TYPE: Hotstring`n"
        logEntry .= "  LINE: " hotstringInfo.line "`n"
        logEntry .= "  TRIGGER: " hotstringInfo.trigger "`n"
        logEntry .= "  REPLACEMENT: " hotstringInfo.replacement "`n"
        logEntry .= "  OPTIONS: " hotstringInfo.options "`n"
        logEntry .= "  CONTENT: " hotstringInfo.content "`n"
    }

    logEntry .= "----------------------------------------`n"

    ; Append to log file
    try {
        FileAppend(logEntry, logFile)
    } catch as err {
        ; If append fails, try creating a new file
        try {
            FileDelete(logFile)
            FileAppend("========== HotkeyDetails Log ==========`n", logFile)
            FileAppend("Started: " timestamp "`n`n", logFile)
            FileAppend(logEntry, logFile)
        } catch {
            ; Silent fail if we can't log
        }
    }
}

; Enhanced script summary logging
logScriptSummary(scriptInfo, hotkeyCount, hotstringCount, commandList) {
    static logFile := A_ScriptDir "\ScriptSummary.log"

    ; Format the timestamp
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    ; Create header if file doesn't exist
    if (!FileExist(logFile)) {
        FileAppend("========== Script Summary Log ==========`n", logFile)
        FileAppend("Started: " timestamp "`n`n", logFile)
    }

    ; Format the log entry
    logEntry := "[" timestamp "] SCRIPT SUMMARY: " scriptInfo.scriptName "`n"
    logEntry .= "  PATH: " scriptInfo.scriptPath "`n"
    logEntry .= "  HOTKEYS: " hotkeyCount "`n"
    logEntry .= "  HOTSTRINGS: " hotstringCount "`n"

    if (commandList && commandList.Length > 0) {
        logEntry .= "  COMMANDS:`n"
        for i, cmd in commandList {
            logEntry .= "    " i ". " (cmd.type = "k" ? "Hotkey: " : "Hotstring: ") cmd.command "`n"
            if (i >= 10) {
                logEntry .= "    (and " (commandList.Length - 10) " more...)`n"
                break
            }
        }
    } else {
        logEntry .= "  COMMANDS: None found`n"
    }

    logEntry .= "----------------------------------------`n"

    ; Append to log file
    try {
        FileAppend(logEntry, logFile)
    } catch as err {
        ; If append fails, try creating a new file
        try {
            FileDelete(logFile)
            FileAppend("========== Script Summary Log ==========`n", logFile)
            FileAppend("Started: " timestamp "`n`n", logFile)
            FileAppend(logEntry, logFile)
        } catch {
            ; Silent fail if we can't log
        }
    }
}

; Function to integrate into loadCommands() to analyze script content
analyzeScriptContent(scriptPath, scriptName) {
    ; Log that we're analyzing this script
    logToFile("Analyzing content of: " scriptName)

    try {
        ; Read the script file
        fileContent := FileRead(scriptPath)

        ; Get basic statistics
        lineCount := StrSplit(fileContent, "`n", "`r").Length
        charCount := StrLen(fileContent)

        ; Check for header format
        hasProperHeader := RegExMatch(fileContent, "^\s*;={10,}\s+\w+\s+v\d+\.\d+\.\d+\s+={10,}")
        hasProperFooter := RegExMatch(fileContent, ";={10,}\s+End of \w+\s+={10,}")

        ; Check for common includes
        hasSingleInstance := InStr(fileContent, "#SingleInstance")
        hasRequiresV2 := InStr(fileContent, "#Requires AutoHotkey v2")

        ; Log the analysis results
        logEntry := "  Script Analysis Results:`n"
        logEntry .= "    Lines: " lineCount "`n"
        logEntry .= "    Characters: " charCount "`n"
        logEntry .= "    Has proper header: " (hasProperHeader ? "Yes" : "No") "`n"
        logEntry .= "    Has proper footer: " (hasProperFooter ? "Yes" : "No") "`n"
        logEntry .= "    Has #SingleInstance: " (hasSingleInstance ? "Yes" : "No") "`n"
        logEntry .= "    Has #Requires AHK v2: " (hasRequiresV2 ? "Yes" : "No") "`n"

        logToFile(logEntry)

        return {
            lineCount: lineCount,
            charCount: charCount,
            hasProperHeader: hasProperHeader,
            hasProperFooter: hasProperFooter,
            hasSingleInstance: hasSingleInstance,
            hasRequiresV2: hasRequiresV2
        }
    } catch as err {
        logToFile("  ERROR analyzing script content: " err.Message)
        return false
    }
}

;================= End of HotkeyLogger =================