;================= ScriptScanner v1.0.0 =================
; Script scanning functionality - detects running AutoHotkey scripts, extracts
; hotkeys and hotstrings from script files, and processes both direct code and
; Triggers-based commands with conflict detection.


#Requires AutoHotkey v2.0.2+
#SingleInstance Force

; This module requires these global functions defined elsewhere:
; - logToFile: From CoreModule.ahk
; - StrJoin: From CoreModule.ahk (if used)
; All includes are managed in the main script as preferred

; Retrieve running AutoHotkey scripts
getRunningScripts() {
    arrayScripts := []
    DetectHiddenWindows(true)

    logToFile("========== Script Detection ==========", false)
    logToFile("Time: " A_Now)
    logToFile("Starting script detection...")

    ; Log skip list in a more readable format
    skipListStr := ""
    for i, script in arraySkipScriptList {
        skipListStr .= (i > 1 ? "`n- " : "- ") script
    }
    logToFile("Scripts to be skipped:`n" skipListStr)

    ; First try to find using ahk_class
    winList := WinGetList("ahk_class AutoHotkey")
    scriptCount := 0

    logToFile("Looking for scripts by window class 'AutoHotkey'...")

    for window in winList {
        scriptPath := WinGetTitle("ahk_id " window)
        scriptPath := RegExReplace(scriptPath, "\s+-\s+AutoHotkey.*$")

        ; Extract script name for skip check
        SplitPath(scriptPath, &scriptName)

        ; Log the script being checked
        logToFile("Checking script: " scriptName " (" scriptPath ")")

        ; Check if script should be skipped - first check exact path matches
        shouldSkip := false
        for skipItem in arraySkipScriptList {
            if (InStr(skipItem, "\")) {
                ; This is a full path in the skip list - check for exact match
                if (scriptPath = skipItem) {
                    logToFile("  YES - Skipping exact path match: " skipItem)
                    shouldSkip := true
                    break
                }
            }
            else if (scriptName = skipItem) {
                ; This is a filename in the skip list - check for exact match
                logToFile("  YES - Skipping exact filename match: " skipItem)
                shouldSkip := true
                break
            }
        }

        if (shouldSkip) {
            logToFile("  SKIPPING: Script will not be processed")
            continue
        }

        ; If we get here, script should be processed
        scriptCount++
        logToFile("  NO - Script will be processed: " scriptName)
        logToFile("  PROCESSING: This script will be scanned")

        ; Only add if it appears to be a valid path
        if (FileExist(scriptPath)) {
            arrayScripts.Push({hwnd: window, path: scriptPath})
            logToFile("  Added script #" scriptCount ": " scriptPath)
        } else {
            logToFile("  ERROR: Script path appears invalid: " scriptPath)
        }
    }

    ; If we still don't have enough scripts, add the current script as a fallback
    if (arrayScripts.Length = 0) {
        logToFile("No scripts found. Adding current script as fallback.")
        arrayScripts.Push({hwnd: A_ScriptHwnd, path: A_ScriptFullPath})
    }

    ; Summary
    logToFile("Script detection complete. Found " arrayScripts.Length " scripts to process.")

    ; Display detected script count
    debugInfo := "Script Detection Results:`n`n"
    debugInfo .= "Script count: " arrayScripts.Length "`n`n"

    ; List all the scripts found
    if (arrayScripts.Length > 0) {
        debugInfo .= "Scripts found:`n"
        for i, scriptInfo in arrayScripts {
            debugInfo .= i ": " scriptInfo.path "`n"
        }
    }

    logToFile(debugInfo)
    return arrayScripts
}

; Get script details from window handle or path
getScript(scriptInfo) {
    if (IsObject(scriptInfo)) {
        if (scriptInfo.HasOwnProp("hwnd") && scriptInfo.HasOwnProp("path")) {
            hwnd := scriptInfo.hwnd
            scriptPath := scriptInfo.path
        } else {
            logToFile("ERROR: Invalid scriptInfo object passed to getScript()")
            return {hwnd: 0, scriptPath: "", scriptName: "", scriptDir: ""}
        }
    } else {
        ; Legacy behavior - assume scriptInfo is just an hwnd
        hwnd := scriptInfo
        title := WinGetTitle("ahk_id " hwnd)
        scriptPath := RegExReplace(title, "\s+-\s+AutoHotkey.*$")
    }

    ; Verify the script path exists
    if (!FileExist(scriptPath)) {
        logToFile("WARNING: Script path does not exist: " scriptPath)
    }

    ; Get script name and directory
    SplitPath(scriptPath, &scriptName, &scriptDir)

    ; Log script information for debugging
    debugInfo := "Script details:`n"
    debugInfo .= "hwnd: " hwnd "`n"
    debugInfo .= "Script Path: " scriptPath "`n"
    debugInfo .= "Script Name: " scriptName "`n"
    debugInfo .= "Script Dir: " scriptDir "`n"

    logToFile(debugInfo)

    return {hwnd: hwnd, scriptPath: scriptPath, scriptName: scriptName, scriptDir: scriptDir}
}

; Load hotkeys and hotstrings from scripts - FIXED WITH WORKING REGEX AND COMMAND EXTRACTION
loadCommands(arrayScripts) {
    ; FIXED: Simple working regex patterns
    hotkeyRegex := "^(?<hk>\S+)::"                    ; Simple pattern that works with #h::
    hotstringRegex := "^(?!$)\s*:(?<hsopts>(?:[*?BCKOPRTXZ0-9]|S(?:I|E|P))*):(?<hs>.*?)::(?<hstext>.*?)(?<comment>;.*?)?\s*$"

    hotkeyCount := 0
    hotstringCount := 0
    triggersCount := 0
    global arrayBaseList := []
    global mapScriptList := Map()

    ; Array to track scanned scripts
    global gScriptCount := arrayScripts.Length

    logToFile("========== Script Content Scanning ==========")
    logToFile("Starting to scan " arrayScripts.Length " scripts for hotkeys and hotstrings...")

    ; Log the regex patterns being used
    logToFile("REGEX PATTERNS:")
    logToFile("  Hotkey regex: " hotkeyRegex)
    logToFile("  Hotstring regex: " hotstringRegex)

    for index, script in arrayScripts {
        cs := getScript(script)

        logToFile("Scanning script: " cs.scriptName " (" cs.scriptPath ")")

        try {
            scriptContents := FileRead(cs.scriptPath)
            scriptLineCount := StrSplit(scriptContents, "`n", "`r").Length
            logToFile("  Successfully read file: " scriptLineCount " lines")

            ; Log the actual file contents for debugging
            logToFile("  FILE CONTENTS:")
            fileLines := StrSplit(scriptContents, "`n", "`r")
            for lineIndex, lineContent in fileLines {
                logToFile("    Line " lineIndex ": '" lineContent "'")
            }

        } catch as err {
            logToFile("  ERROR reading file: " err.Message)
            continue
        }

        matched := false
        commentBlock := false
        localHotkeyCount := 0
        localHotstringCount := 0
        localTriggersCount := 0
        matchedLines := []

        ; First scan for standard hotkeys/hotstrings in the script content
        logToFile("  STARTING LINE-BY-LINE ANALYSIS:")

        for lineNum, line in StrSplit(scriptContents, "`n", "`r") {
            logToFile("    Processing line " lineNum ": '" line "'")

            ; Check for comment blocks
            if (RegExMatch(line, "^\s*(\/\*|\((?!.*\)))")) {
                commentBlock := true
                logToFile("      -> Comment block START detected")
            }
            else if (RegExMatch(line, "^\s*(\*\/|\))")) {
                commentBlock := false
                logToFile("      -> Comment block END detected")
            }

            ; Skip empty lines, comment blocks, and single-line comments
            if (!line) {
                logToFile("      -> SKIP: Empty line")
                continue
            }
            if (commentBlock) {
                logToFile("      -> SKIP: Inside comment block")
                continue
            }
            if (RegExMatch(line, "^\s*;.*?$")) {
                logToFile("      -> SKIP: Single-line comment")
                continue
            }

            logToFile("      -> TESTING for hotkey/hotstring patterns...")

            match := {}
            command := ""
            description := ""
            lineType := ""

            ; Test hotkey pattern with FIXED simple regex and enhanced command extraction
            logToFile("      -> Testing hotkey regex: " hotkeyRegex)
            if (RegExMatch(line, hotkeyRegex, &matchHotkey)) {
                logToFile("      -> HOTKEY MATCH FOUND!")
                logToFile("         Full match object keys: " GetMatchKeys(&matchHotkey))
                logToFile("         matchHotkey type: " Type(matchHotkey))

                ; Try multiple ways to extract the command
                command := ""
                if (IsObject(matchHotkey) && matchHotkey.HasOwnProp("hk")) {
                    command := Trim(matchHotkey.hk)
                    logToFile("         Extracted hotkey command via .hk property: '" command "'")
                } else if (IsObject(matchHotkey) && matchHotkey.HasOwnProp("1")) {
                    command := Trim(matchHotkey[1])
                    logToFile("         Extracted hotkey command via [1] index: '" command "'")
                } else {
                    ; Fallback: extract manually from the line
                    colonPos := InStr(line, "::")
                    if (colonPos > 0) {
                        command := Trim(SubStr(line, 1, colonPos - 1))
                        logToFile("         Extracted hotkey command manually: '" command "'")
                    } else {
                        logToFile("         ERROR: Could not extract hotkey command")
                        command := ""
                    }
                }

                ; Ensure command is not empty
                if (command = "") {
                    logToFile("         WARNING: Command is empty, using fallback extraction")
                    colonPos := InStr(line, "::")
                    if (colonPos > 0) {
                        command := Trim(SubStr(line, 1, colonPos - 1))
                        logToFile("         Fallback command: '" command "'")
                    }
                }

                ; Extract comment manually since simple regex doesn't capture it
                description := ""
                if (InStr(line, ";")) {
                    commentPos := InStr(line, ";")
                    commentText := SubStr(line, commentPos + 1)
                    description := Trim(commentText)
                    logToFile("         Extracted comment manually: '" description "'")
                } else {
                    logToFile("         No comment found")
                }

                lineType := "hotkey"
                hotkeyCount++
                localHotkeyCount++
                logToFile("         -> HOTKEY CONFIRMED: '" command "' with description: '" description "'")
            }
            else {
                logToFile("      -> No hotkey match")

                ; Keep simple debugging for troubleshooting
                if (InStr(line, "::")) {
                    logToFile("         Line contains '::' but didn't match hotkey pattern")
                    colonPos := InStr(line, "::")
                    beforeColon := SubStr(line, 1, colonPos - 1)
                    logToFile("         Text before '::': '" beforeColon "'")

                    ; Test the simple pattern directly
                    if (RegExMatch(beforeColon, "^\S+$")) {
                        logToFile("         Should have matched! Pattern ^\S+$ works on '" beforeColon "'")
                    } else {
                        logToFile("         Pattern ^\S+$ doesn't match '" beforeColon "'")
                    }
                } else {
                    logToFile("         Line does NOT contain '::' - not a hotkey")
                }
            }

            ; Test hotstring pattern
            logToFile("      -> Testing hotstring regex: " hotstringRegex)
            if (RegExMatch(line, hotstringRegex, &matchHotstring)) {
                logToFile("      -> HOTSTRING MATCH FOUND!")

                command := Trim(matchHotstring.hs)
                logToFile("         Extracted hotstring: '" command "'")

                ; For hotstrings, prefer the replacement text, then comment
                if (matchHotstring.hstext && Trim(matchHotstring.hstext) != "") {
                    description := Trim(matchHotstring.hstext)
                    logToFile("         Using replacement text as description: '" description "'")
                } else if (matchHotstring.HasOwnProp("comment") && matchHotstring.comment) {
                    description := Trim(RegExReplace(matchHotstring.comment, "^;\s*"))
                    logToFile("         Using comment as description: '" description "'")
                } else {
                    description := ""
                    logToFile("         No description found")
                }

                lineType := "hotstring"
                hotstringCount++
                localHotstringCount++
                logToFile("         -> HOTSTRING CONFIRMED: " command)
            }
            else {
                logToFile("      -> No hotstring match")
            }

            ; Check for Hotkey/Hotstring function calls
            if (!lineType && (InStr(line, "Hotkey(", true) || InStr(line, "Hotkey,", true))) {
                logToFile("      -> Found Hotkey function call")
                ; Try to extract the key from Hotkey call
                line := Trim(line)
                startPos := InStr(line, ",") + 1
                endPos := InStr(line, ",", true, startPos) || StrLen(line) + 1
                command := Trim(SubStr(line, startPos, endPos - startPos))

                if (command != "") {
                    if (InStr(line, ";")) {
                        commentPart := Trim(SubStr(line, InStr(line, ";") + 1))
                        description := commentPart
                    } else {
                        description := ""
                    }

                    lineType := "hotkey"
                    hotkeyCount++
                    localHotkeyCount++
                    logToFile("         -> HOTKEY FUNCTION CONFIRMED: " command)
                }
            }
            else if (!lineType && InStr(line, "Hotstring(", true)) {
                logToFile("      -> Found Hotstring function call")
                ; Try to extract from Hotstring call
                line := Trim(line)
                startPos := InStr(line, "Hotstring(") + 11
                endPos := InStr(line, ",", true, startPos) - 1

                if (endPos > startPos) {
                    command := SubStr(line, startPos, endPos - startPos)

                    if (InStr(line, ";")) {
                        commentPart := Trim(SubStr(line, InStr(line, ";") + 1))
                        description := commentPart
                    } else {
                        description := ""
                    }

                    lineType := "hotstring"
                    hotstringCount++
                    localHotstringCount++
                    logToFile("         -> HOTSTRING FUNCTION CONFIRMED: " command)
                }
            }

            ; If we identified a hotkey or hotstring, add it to our tracking
            if (lineType) {
                matched := true
                matchedLines.Push({
                    line: lineNum,
                    content: line,
                    type: lineType,
                    command: command,
                    description: description
                })

                ; Check for conflicts with Windows shortcuts (only for hotkeys)
                conflictInfo := false
                if (lineType = "hotkey") {
                    conflictInfo := CheckHotkeyConflict(command)
                    if (conflictInfo) {
                        logToFile("         -> CONFLICT DETECTED: " conflictInfo.windowsKey)
                    }
                }

                ; Add to the global array with preserved description and conflict info
                mapScriptList[cs.scriptName] := true
                arrayBaseList.Push({
                    command: command,
                    description: description,
                    file: cs.scriptName,
                    line: lineNum,
                    type: (lineType = "hotkey") ? "k" : "s",
                    hwnd: cs.hwnd,
                    status: true,
                    source: "direct code",
                    conflict: conflictInfo
                })

                ; Enhanced logging for debugging with conflict info
                conflictText := conflictInfo ? " [CONFLICT: " conflictInfo.windowsKey "]" : ""
                logToFile("         -> ADDED TO ARRAY: type=" lineType ", command='" command "', desc='" description "', line=" lineNum conflictText)
            } else {
                logToFile("      -> No match found for this line")
            }
        }

        ; Check for Triggers class usage
        hasTriggers := InStr(scriptContents, "Triggers.Add") ||
                      InStr(scriptContents, "Triggers.AddHotkey") ||
                      InStr(scriptContents, "Triggers.AddMouse") ||
                      InStr(scriptContents, "Triggers.AddHotstring")

        if (hasTriggers) {
            logToFile("  Triggers class usage detected in script: " cs.scriptName)

            ; Now check if settings.ini exists
            iniPath := cs.scriptDir "\settings.ini"
            if (FileExist(iniPath)) {
                logToFile("  Found settings.ini file: " iniPath)

                ; Process Triggers INI regardless of whether we found direct hotkeys
                ; Scripts can have BOTH direct hotkeys AND Triggers-based hotkeys
                logToFile("  Checking for ScanTriggersIni function...")

                ; Check for the ScanTriggersIni function and call it if it exists
                functionFound := false

                try {
                    ; In AHK v2, we check function existence through a try-catch
                    logToFile("  Attempting to call ScanTriggersIni function...")
                    triggersStats := ScanTriggersIni(cs, scriptContents)
                    functionFound := true
                    logToFile("  ScanTriggersIni function called successfully")

                    if (triggersStats.triggersFound) {
                        logToFile("  Triggers class confirmed in script")

                        if (triggersStats.iniFound) {
                            logToFile("  Processed settings.ini: " triggersStats.iniPath)
                            logToFile("  Added: "
                                     triggersStats.hotkeysAdded " hotkeys, "
                                     triggersStats.hotstringsAdded " hotstrings, and "
                                     triggersStats.mouseTriggersAdded " mouse triggers from INI")

                            localTriggersCount := triggersStats.hotkeysAdded +
                                                 triggersStats.hotstringsAdded +
                                                 triggersStats.mouseTriggersAdded

                            ; Update global counts - ADD to existing counts, don't replace
                            hotkeyCount += triggersStats.hotkeysAdded + triggersStats.mouseTriggersAdded
                            hotstringCount += triggersStats.hotstringsAdded
                            triggersCount += localTriggersCount
                        } else {
                            logToFile("  No entries found in settings.ini")
                        }
                    } else {
                        logToFile("  No active Triggers found in script despite usage")
                    }
                } catch as err {
                    functionFound := false
                    logToFile("  ERROR: ScanTriggersIni function error: " err.Message)

                    ; Provide details about the error for troubleshooting
                    logToFile("  Full error details: " err.Extra " (Line: " err.Line ")")

                    ; If we can't process with the function, provide a fallback
                    if (hasTriggers && FileExist(iniPath)) {
                        logToFile("  Attempting fallback processing of settings.ini...")

                        try {
                            ; Basic fallback processing
                            hotkeySection := IniRead(iniPath, "Hotkeys")
                            if (hotkeySection) {
                                sectionLines := StrSplit(hotkeySection, "`n", "`r")
                                logToFile("  Found " sectionLines.Length " entries in Hotkeys section")

                                for _, line in sectionLines {
                                    logToFile("    Entry: " line)
                                }
                            } else {
                                logToFile("  No Hotkeys section found in settings.ini")
                            }
                        } catch as err2 {
                            logToFile("  Fallback processing error: " err2.Message)
                        }
                    }
                }

                if (!functionFound) {
                    logToFile("  ScanTriggersIni function not found or error occurred")
                    logToFile("  Make sure TriggersIniScanner.ahk is included properly")

                    ; Check if we can find the module
                    if (FileExist(A_ScriptDir "\TriggersIniScanner.ahk")) {
                        logToFile("  TriggersIniScanner.ahk exists in script directory")
                    } else {
                        logToFile("  TriggersIniScanner.ahk not found in script directory")
                    }
                }
            } else {
                logToFile("  No settings.ini file found at: " iniPath)
                ; Even without settings.ini, log the Triggers calls we found for reference
                logToFile("  Script uses Triggers class but has no settings.ini - only direct Triggers calls will be visible")
            }
        } else {
            logToFile("  No Triggers class usage detected in script")
        }

        ; Log the results for this script - include BOTH direct and Triggers counts
        totalFound := localHotkeyCount + localHotstringCount + localTriggersCount
        logToFile("  FINAL SUMMARY for " cs.scriptName ":")
        logToFile("    Direct hotkeys found: " localHotkeyCount)
        logToFile("    Direct hotstrings found: " localHotstringCount)
        logToFile("    Triggers-based commands: " localTriggersCount)
        logToFile("    Total commands found: " totalFound)

        if (totalFound = 0) {
            logToFile("    *** NO COMMANDS FOUND - CHECK REGEX PATTERNS ***")
        }

        ; Log first 5 matched direct lines for debugging
        if (matchedLines.Length > 0) {
            maxToShow := Min(matchedLines.Length, 5)
            logToFile("  First " maxToShow " matched DIRECT lines:")
            for i, item in matchedLines {
                if (i > maxToShow)
                    break
                logToFile("    Line " item.line ": " Trim(item.content) " (" item.type ") - Command: " item.command " - Desc: '" item.description "'")
            }
        }
    }

    ; Update the global counts for later use
    global gHotkeyCount := hotkeyCount
    global gHotstringCount := hotstringCount

    logToFile("FINAL TOTALS: " hotkeyCount " hotkeys, " hotstringCount " hotstrings, " triggersCount " Triggers commands")

    ; Debug: Log the first few items in arrayBaseList with their descriptions
    if (arrayBaseList.Length > 0) {
        logToFile("Debug: First 5 items in arrayBaseList with descriptions:")
        maxItems := Min(arrayBaseList.Length, 5)
        Loop maxItems {
            i := A_Index
            item := arrayBaseList[i]
            logToFile("  Item " i ": command='" item.command "', desc='" item.description "', type=" (item.type = "k" ? "hotkey" : "hotstring")
                    ", file=" item.file ", line=" item.line ", source=" (item.HasOwnProp("source") ? item.source : "unknown"))
        }
    } else {
        logToFile("Debug: arrayBaseList is empty!")
    }
}

; Helper function to debug match objects - ENHANCED
GetMatchKeys(matchObj) {
    if (!IsObject(matchObj)) {
        return "Not an object - type: " Type(matchObj)
    }

    keys := ""
    try {
        ; Try to access named capture groups
        if (matchObj.HasOwnProp("hk"))
            keys .= "hk='" matchObj.hk "' "
        if (matchObj.HasOwnProp("comment"))
            keys .= "comment='" matchObj.comment "' "

        ; Try to access numbered capture groups
        if (matchObj.HasOwnProp("1"))
            keys .= "[1]='" matchObj[1] "' "
        if (matchObj.HasOwnProp("2"))
            keys .= "[2]='" matchObj[2] "' "

        ; Try Count property
        if (matchObj.HasOwnProp("Count"))
            keys .= "Count=" matchObj.Count " "

        ; Try Len property
        if (matchObj.HasOwnProp("Len"))
            keys .= "Len=" matchObj.Len " "

        ; Try Pos property
        if (matchObj.HasOwnProp("Pos"))
            keys .= "Pos=" matchObj.Pos " "

    } catch as err {
        keys .= "Error accessing properties: " err.Message
    }

    return keys != "" ? keys : "No accessible properties found"
}

;================= End of ScriptScanner =================