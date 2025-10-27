;================= TriggersIniScanner v1.0.0 =================
; Triggers class ini file scanner - scans scripts for Triggers class usage
; and processes associated settings.ini files to extract hotkeys and hotstrings
; defined through the Triggers framework.

; Explicitly declare global functions and variables used from other modules
global logToFile
global arrayBaseList
global mapScriptList

; Scans a script for references to the Triggers class and then checks
; for and processes the associated settings.ini file
ScanTriggersIni(scriptInfo, scriptContents) {
    logToFile("Scanning for Triggers class usage in: " scriptInfo.scriptName)

    ; Initialize return statistics
    stats := {
        triggersFound: false,
        iniFound: false,
        iniPath: "",
        hotkeysAdded: 0,
        hotstringsAdded: 0,
        mouseTriggersAdded: 0
    }

    ; Check if script uses Triggers class (case insensitive)
    if (!RegExMatch(scriptContents, "i)Triggers\.(Add|AddHotkey|AddMouse|AddHotstring)")) {
        logToFile("  No Triggers class usage detected")
        return stats
    }

    ; Found Triggers class usage
    stats.triggersFound := true
    logToFile("  Triggers class usage detected")

    ; Extract all Triggers.Add* function calls to get function names
    triggerCalls := []
    for lineNum, line in StrSplit(scriptContents, "`n", "`r") {
        ; Skip comments and empty lines
        if (!line || RegExMatch(line, "^\s*;.*?$"))
            continue

        ; Look for Triggers.Add* calls
        if (RegExMatch(line, "i)Triggers\.(Add|AddHotkey|AddMouse|AddHotstring)", &matchType)) {
            type := StrLower(matchType[1] || "Add")  ; Normalize type name

            ; Extract the function name using simple regex
            funcName := ""
            if (RegExMatch(line, "i)Triggers\.[^(]+\(\s*(\w+)", &funcMatch))
                funcName := funcMatch[1]

            if (funcName) {
                logToFile("  Found Triggers." type " call: " funcName " at line " lineNum)
                triggerCalls.Push({
                    type: type,
                    funcName: funcName,
                    line: lineNum
                })
            }
        }
    }

    logToFile("  Found " triggerCalls.Length " Triggers calls in script")

    ; If no Triggers calls found, return early
    if (triggerCalls.Length = 0) {
        logToFile("  No valid Triggers function calls found despite usage")
        return stats
    }

    ; Look for settings.ini in script directory
    iniPath := scriptInfo.scriptDir "\settings.ini"

    if (!FileExist(iniPath)) {
        logToFile("  settings.ini not found at: " iniPath)

        ; Since no INI file found, report all Triggers calls as direct hotkeys
        for call in triggerCalls {
            logToFile("  Adding Triggers." call.type " call for " call.funcName " as direct hotkey (no INI)")

            ; Add to the global array with a note about missing INI
            mapScriptList[scriptInfo.scriptName] := true

            ; Determine type based on the call type
            typeChar := "k"  ; Default to hotkey
            if (call.type = "AddHotstring")
                typeChar := "s"

            arrayBaseList.Push({
                command: call.funcName,
                description: "Triggers." call.type " call with no settings.ini",
                file: scriptInfo.scriptName,
                line: call.line,
                type: typeChar,
                hwnd: scriptInfo.hwnd,
                status: true,
                source: "Triggers (no INI)"
            })

            ; Update stats
            if (call.type = "AddHotstring")
                stats.hotstringsAdded++
            else if (call.type = "AddMouse")
                stats.mouseTriggersAdded++
            else
                stats.hotkeysAdded++
        }

        return stats
    }

    stats.iniFound := true
    stats.iniPath := iniPath
    logToFile("  Found settings.ini at: " iniPath)

    ; Process the ini file to extract hotkeys
    try {
        ; Read all hotkeys from the ini file
        hotkeySection := IniRead(iniPath, "Hotkeys")

        if (hotkeySection = "") {
            logToFile("  No hotkeys found in settings.ini")
            return stats
        }

        ; Build a map of function names to track which ones are in the INI
        iniMappedFuncs := Map()

        ; Process each line in the Hotkeys section
        for i, line in StrSplit(hotkeySection, "`n", "`r") {
            if (RegExMatch(line, "(.*)=(.*)", &r)) {
                funcName := r[1]
                hotkeyDef := r[2]

                if (hotkeyDef = "") {
                    continue
                }

                ; Mark this function as found in the INI
                iniMappedFuncs[funcName] := hotkeyDef

                ; Get label and type from ini
                label := IniRead(iniPath, "Label", funcName, funcName)
                type := IniRead(iniPath, "Dropdown", funcName, "2") ; Default to hotkey
                title := IniRead(iniPath, "Title", funcName, "")

                ; Determine type text for display
                typeText := "k" ; Default to hotkey

                if (type = "1") {
                    typeText := "k" ; Mouse trigger is still a hotkey type
                    stats.mouseTriggersAdded++
                } else if (type = "2") {
                    typeText := "k"
                    stats.hotkeysAdded++
                } else if (type = "3") {
                    typeText := "s"
                    stats.hotstringsAdded++
                }

                ; Add to the global array
                mapScriptList[scriptInfo.scriptName] := true

                ; Format the description with the label and function name
                description := label
                if (title) {
                    description .= " - " title
                }
                description .= " (" funcName ")"

                ; Add to global array with settings.ini hotkey identifier
                arrayBaseList.Push({
                    command: hotkeyDef,
                    description: description,
                    file: scriptInfo.scriptName,
                    line: 0, ; No specific line since it's from ini
                    type: typeText,
                    hwnd: scriptInfo.hwnd,
                    status: true,
                    source: "settings.ini"
                })

                logToFile("  Added from settings.ini: " (typeText = "k" ? "Hotkey" : "Hotstring") " - " hotkeyDef " - " description)
            }
        }

        ; Now check for Triggers calls not in the INI and add them too
        for call in triggerCalls {
            if (!iniMappedFuncs.Has(call.funcName)) {
                logToFile("  Adding Triggers." call.type " call for " call.funcName " not found in INI")

                ; Add to the global array
                mapScriptList[scriptInfo.scriptName] := true

                ; Determine type based on the call type
                typeChar := "k"  ; Default to hotkey
                if (call.type = "AddHotstring")
                    typeChar := "s"

                arrayBaseList.Push({
                    command: call.funcName,
                    description: "Triggers." call.type " call (not in settings.ini)",
                    file: scriptInfo.scriptName,
                    line: call.line,
                    type: typeChar,
                    hwnd: scriptInfo.hwnd,
                    status: true,
                    source: "Triggers (not in INI)"
                })

                ; Update stats
                if (call.type = "AddHotstring")
                    stats.hotstringsAdded++
                else if (call.type = "AddMouse")
                    stats.mouseTriggersAdded++
                else
                    stats.hotkeysAdded++
            }
        }
    } catch as err {
        logToFile("  ERROR processing settings.ini: " err.Message)
    }

    ; Return stats
    return stats
}

;================= End of TriggersIniScanner =================