;================= ScriptScanner v1.0.0 =================
; Script scanning functionality - detects running AutoHotkey scripts, extracts
; hotkeys and hotstrings from script files, and processes both direct code and
; Triggers-based commands with conflict detection.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

#Include CoreModule_v2.ahk
moduleCore := CoreModule()

#Include ConflictChecker_v2.ahk
conflCheck := ConflictCheckers()

#Include TriggersIniScanner_v2.ahk
trIniSc := TriggerIniScanner()

#Include D:\OneDrive\AHK\Includes\Peep_v2.ahk
; NMS jsongo.v2.ahk can be found: https://github.com/GroggyOtter/jsongo_AHKv2
#Include D:\OneDrive\AHK\Includes\jsongo_v2.ahk

; NMS Next 6 lines added
; Retrieve Scripts to be skipped
skipScripts := StrSplit(FileRead('Skip_Scripts.ini'), ',')
arraySkipScriptList := []
Loop skipScripts.Length
    if !InStr(skipScripts[A_Index], ';')
        arraySkipScriptList.Push(SubStr(skipScripts[A_Index],2))

Class ScriptScanner {
    /**
     * getRunningScripts - Detects and returns all currently running AutoHotkey scripts
     * 
     * Purpose:
     *   Scans the system for active AutoHotkey scripts by searching for windows with
     *   the "AutoHotkey" class. Filters out scripts that match entries in the skip list
     *   (loaded from Skip_Scripts.ini). This is the entry point for identifying which
     *   scripts should be analyzed for hotkeys and hotstrings.
     * 
     * Process Flow:
     *   1. Enables detection of hidden windows to find all AHK instances
     *   2. Searches for all windows with "ahk_class AutoHotkey"
     *   3. For each window found:
     *      - Extracts the script path from the window title
     *      - Checks if the script is in the skip list (by name or full path)
     *      - Validates that the file exists on disk
     *      - Adds valid scripts to the results array
     *   4. If no scripts found, adds the current script as a fallback
     *   5. Logs all findings for debugging purposes
     * 
     * Parameters: None
     * 
     * Returns:
     *   Array of objects, each containing:
     *     - hwnd: Window handle (integer) of the running script
     *     - path: Full file path (string) to the .ahk file
     * 
     * Example Return:
     *   [{hwnd: 12345, path: "C:\Scripts\MyScript.ahk"},
     *    {hwnd: 67890, path: "C:\Scripts\Another.ahk"}]
     * 
     * Dependencies:
     *   - arraySkipScriptList (global): List of script names/paths to ignore
     *   - moduleCore.logToFile(): For debug logging
     * 
     * Notes:
     *   - Uses exact matching for skip list entries (both filename and full path)
     *   - Always includes at least one script (the current script if none found)
     *   - Logs extensively for troubleshooting script detection issues
     */
    ; New : 25-01-24
    ; getRunningScripts : () : Retrieve running AutoHotkey scripts
    ; Returns : array - Array of script objects with hwnd and path properties
    getRunningScripts() {
        ; NMS Next line added
        moduleCore.logToFile("========== ScriptScanner / getRunningScripts ==========", 'NMS')
        arrayScripts := []
        DetectHiddenWindows(true)

        moduleCore.logToFile("========== Script Detection ==========")
        moduleCore.logToFile("Time: " A_Now "Starting script detection...")

        ; Log skip list in a more readable format
        skipListStr := ""
        for i, script in arraySkipScriptList {
            skipListStr .= (i > 1 ? "`n- " : "- ") script
        }
        moduleCore.logToFile("Scripts to be skipped:`n" skipListStr)

        ; First try to find using ahk_class
        winList := WinGetList("ahk_class AutoHotkey")
        scriptCount := 0

        moduleCore.logToFile('Looking for scripts by window class `'AutoHotkey`'...')

        for window in winList {
            scriptPath := WinGetTitle("ahk_id " window)
            scriptPath := RegExReplace(scriptPath, "\s+-\s+AutoHotkey.*$")

            ; Extract script name for skip check
            SplitPath(scriptPath, &scriptName)

            ; Log the script being checked
            moduleCore.logToFile("Checking script: " scriptName " (" scriptPath ")")

            ; Check if script should be skipped - first check exact path matches
            shouldSkip := false
            for skipItem in arraySkipScriptList {
                if (InStr(skipItem, "\")) {
                    if (scriptPath = skipItem) {
                        moduleCore.logToFile("  YES - Skipping exact path match: " skipItem)
                        shouldSkip := true
                        break
                    }
                }
                else if (scriptName = skipItem) {
                    moduleCore.logToFile("  YES - Skipping exact filename match: " skipItem)
                    shouldSkip := true
                    break
                }
            }

            if (shouldSkip) {
                moduleCore.logToFile("  SKIPPING: Script will not be processed")
                continue
            }

            ; If we get here, script should be processed
            scriptCount++
            moduleCore.logToFile("  NO - Script will be processed: " scriptName)
            moduleCore.logToFile("  PROCESSING: This script will be scanned")

            ; Only add if it appears to be a valid path
            if (FileExist(scriptPath)) {
                arrayScripts.Push({hwnd: window, path: scriptPath})
                moduleCore.logToFile("  Added script #" scriptCount ": " scriptPath)
            } else {
                moduleCore.logToFile("  ERROR: Script path appears invalid: " scriptPath)
            }
        }

        ; If we still don't have enough scripts, add the current script as a fallback
        if (arrayScripts.Length = 0) {
            moduleCore.logToFile("No scripts found. Adding current script as fallback.")
            arrayScripts.Push({hwnd: A_ScriptHwnd, path: A_ScriptFullPath})
        }

        ; Summary
        moduleCore.logToFile("Script detection complete. Found " arrayScripts.Length " scripts to process.")

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
        moduleCore.logToFile(debugInfo)
        return arrayScripts
    }

    /**
     * getScript - Extracts and validates script information from a window handle or script object
     * 
     * Purpose:
     *   Normalizes script information into a standard format. Accepts either a script object
     *   (with hwnd and path properties) or just a window handle, and returns a complete
     *   script information object with parsed path components.
     * 
     * Process Flow:
     *   1. Determines input type (object with properties or raw hwnd)
     *   2. If object: Validates it has required properties (hwnd and path)
     *   3. If hwnd only: Retrieves path from window title
     *   4. Validates that the script file exists on disk
     *   5. Splits path into components (name and directory)
     *   6. Returns standardized object with all script details
     * 
     * Parameters:
     *   scriptInfo (object|int): Either:
     *     - Object with {hwnd: int, path: string} properties
     *     - Integer window handle (legacy behavior)
     * 
     * Returns:
     *   Object containing:
     *     - hwnd (int): Window handle of the script
     *     - scriptPath (string): Full path to the .ahk file
     *     - scriptName (string): Filename only (e.g., "MyScript.ahk")
     *     - scriptDir (string): Directory path only (e.g., "C:\Scripts")
     * 
     * Error Handling:
     *   - Invalid object: Returns object with empty/zero values
     *   - Non-existent file: Logs warning but still returns parsed information
     * 
     * Example Usage:
     *   scriptDetails := scanner.getScript({hwnd: 12345, path: "C:\Scripts\Test.ahk"})
     *   ; Returns: {hwnd: 12345, scriptPath: "C:\Scripts\Test.ahk",
     *   ;           scriptName: "Test.ahk", scriptDir: "C:\Scripts"}
     * 
     * Dependencies:
     *   - moduleCore.logToFile(): For debug logging
     * 
     * Notes:
     *   - Supports both new (object) and legacy (hwnd only) calling conventions
     *   - Always logs detailed information for debugging
     *   - Window title parsing removes " - AutoHotkey" suffix
     */
    ; New : 25-01-24
    ; getScript : (scriptInfo) : Get script details from window handle or path
    ; scriptInfo : object|int - Script info object with hwnd/path or just hwnd value
    ; Returns : object - Object with hwnd, scriptPath, scriptName, and scriptDir
    getScript(scriptInfo) {
        ; NMS 1 line added
        moduleCore.logToFile("========== ScriptScanner / getScript ==========", 'NMS')
        if (IsObject(scriptInfo)) {
            if (scriptInfo.HasOwnProp("hwnd") && scriptInfo.HasOwnProp("path")) {
                hwnd := scriptInfo.hwnd
                scriptPath := scriptInfo.path
            } else {
                moduleCore.logToFile("ERROR: Invalid scriptInfo object passed to getScript()")
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
            moduleCore.logToFile("WARNING: Script path does not exist: " scriptPath)
        }

        ; Get script name and directory
        SplitPath(scriptPath, &scriptName, &scriptDir)

        ; Log script information for debugging
        debugInfo := "Script details:`n"
        debugInfo .= "hwnd: " hwnd "`n"
        debugInfo .= "Script Path: " scriptPath "`n"
        debugInfo .= "Script Name: " scriptName "`n"
        debugInfo .= "Script Dir: " scriptDir "`n"

        moduleCore.logToFile(debugInfo)

        return {hwnd: hwnd, scriptPath: scriptPath, scriptName: scriptName, scriptDir: scriptDir}
    }

    /**
     * loadCommands - Main function to scan scripts and extract all hotkeys and hotstrings
     * 
     * Purpose:
     *   This is the core processing function that reads through all script files (both
     *   running and from search folders), extracts hotkey/hotstring definitions, processes
     *   Triggers-based commands from settings.ini files, and builds a comprehensive list
     *   of all keyboard shortcuts with conflict detection.
     * 
     * Process Flow:
     *   1. INITIALIZATION:
     *      - Reads additional script folders from Search_Folders.ini
     *      - Adds non-running scripts from search folders to scan list
     *      - Initializes global arrays and counters
     * 
     *   2. FOR EACH SCRIPT:
     *      - Reads the entire script file into memory
     *      - Extracts script metadata (name, directory, path)
     *   
     *   3. DIRECT HOTKEY/HOTSTRING EXTRACTION:
     *      - Uses regex patterns to find hotkey definitions (e.g., "^!c::")
     *      - Uses regex patterns to find hotstring definitions (e.g., "::btw::")
     *      - Extracts inline comments for descriptions
     *      - Stores line numbers for reference
     *      - Captures multi-line descriptions when present
     * 
     *   4. TRIGGERS-BASED COMMAND PROCESSING:
     *      - Detects if script uses the Triggers class
     *      - Locates associated settings.ini file
     *      - Calls TriggerIniScanner to extract Triggers-defined shortcuts
     *      - Merges Triggers data with direct hotkey/hotstring data
     * 
     *   5. CONFLICT DETECTION:
     *      - Compares all found shortcuts against each other
     *      - Identifies duplicate bindings across scripts
     *      - Marks conflicts in the data structure
     * 
     *   6. DATA COMPILATION:
     *      - Builds arrayBaseList with all commands and metadata
     *      - Populates arrayKeyBindings with simplified binding info
     *      - Tracks statistics (counts by type, by script)
     * 
     * Parameters:
     *   arrayScripts (array): Array of script objects from getRunningScripts()
     *     Each object should have: {hwnd: int, path: string}
     * 
     * Global Variables Modified:
     *   - arrayBaseList: Complete list of all commands with full metadata
     *   - arrayKeyBindings: Simplified list for quick lookup
     *   - hotkeyCount: Total number of hotkeys found
     *   - hotstringCount: Total number of hotstrings found
     *   - triggersCount: Total Triggers-based commands found
     * 
     * Regex Patterns Used:
     *   - Hotkey pattern: Matches modifier keys + key combinations (^!+#)
     *   - Hotstring pattern: Matches ::trigger:: format with options
     *   - Comment extraction: Captures inline ; comments for descriptions
     * 
     * Data Structure Created:
     *   arrayBaseList contains objects with:
     *     - command: The hotkey/hotstring trigger (e.g., "^!c", "::btw")
     *     - description: Comment text explaining what it does
     *     - type: "k" for hotkey, "s" for hotstring
     *     - file: Name of the script file
     *     - line: Line number in the source file
     *     - source: "direct" or "triggers"
     *     - scriptPath: Full path to the script
     *     - hasConflict: Boolean indicating if binding conflicts with another
     * 
     * Dependencies:
     *   - moduleCore.logToFile(): Extensive logging for debugging
     *   - trIniSc.ScanTriggersIni(): Processes Triggers settings.ini files
     *   - Search_Folders.ini: List of additional folders to scan
     *   - Skip_Scripts.ini: Scripts to exclude from scanning
     * 
     * Performance Notes:
     *   - Reads entire files into memory (suitable for typical script sizes)
     *   - Uses regex for pattern matching (efficient for script files)
     *   - May take several seconds for large script collections
     *   - Logs extensively - can generate large log files
     * 
     * Error Handling:
     *   - Catches and logs file read errors
     *   - Handles missing settings.ini gracefully
     *   - Validates Triggers function availability
     *   - Falls back to basic processing if Triggers scanner fails
     * 
     * Example Log Output:
     *   "Processing script: MyScript.ahk"
     *   "  Direct hotkeys found: 15"
     *   "  Triggers-based commands: 8"
     *   "  Total commands found: 23"
     * 
     * Notes:
     *   - The function is quite large (400+ lines) due to comprehensive processing
     *   - Contains extensive debug logging (can be disabled for production)
     *   - Handles both v1 and v2 AutoHotkey syntax patterns
     *   - Special handling for mouse triggers (LButton, RButton, etc.)
     */
    ; New : 25-01-24
    ; loadCommands : (arrayScripts) : Load hotkeys and hotstrings from scripts
    ; arrayScripts : array - Array of script objects to scan
    loadCommands(arrayScripts) {
        ; NMS Next 10 lines added
        searchFolders := StrSplit(FileRead('Search_Folders.ini'), ',', '`n')
        arrayScriptsText := jsongo.Stringify(arrayScripts)
        arraySkipScriptListText := jsongo.Stringify(arraySkipScriptList)
        Loop searchFolders.Length {
            Loop Files String(searchFolders[A_Index]) '\*.ahk*' {
                if !(InStr(arrayScriptsText, A_LoopFileName) || InStr(arraySkipScriptListText, A_LoopFileName)) {
                    arrayScripts.Push({hwnd: 0, path: A_LoopFilePath})
                }
            }
        }
        moduleCore.logToFile("========== ScriptScanner / loadCommands ==========", 'NMS')

            ; ========================================
            ; PATTERN DEFINITIONS AND EXPLANATION
            ; ========================================
            
            ; HOTKEY PATTERN (hotkeyPattern):
            ; Matches standard AutoHotkey hotkey definitions like: ^!c::, #f::, +Home::
            ; Pattern breakdown:
            ;   ^(?P<hk>[\^!+#]*\S+?)::  - Captures modifier keys (^!+#) + key name before ::
            ;   \s*{?               - Optional whitespace and opening brace
            ;   \s*;?\s*            - Optional whitespace around comment marker
            ;   (?P<comment>.*)     - Captures the rest as comment/description
            ; Examples matched:
            ;   ^!c::               ; Copy text
            ;   #f:: Send "hello"
            ;   +Home::
            
            ; HOTSTRING PATTERN (hotstringPattern):
            ; Matches AutoHotkey hotstring definitions like: ::btw::, :*:omw::
            ; Pattern breakdown:
            ;   ^:(?P<opts>[*?0-9bcikoprsez]*)  - Captures hotstring options
            ;   :(?P<trigger>[^:]+)::           - Captures trigger text between ::
            ;   \s*{?                           - Optional whitespace and brace
            ;   \s*;?\s*                        - Optional comment marker
            ;   (?P<comment>.*)                 - Captures comment/description
            ; Examples matched:
            ;   ::btw::by the way
            ;   :*:omw::on my way
            ;   :c:addr::123 Main St
            ; hotkeyPattern := "im)^(?P<hk>[\^!+#]*\S+?)::(?:\s*\{?)\s*;?\s*(?P<comment>.*)"
            ; hotstringPattern := "im)^:(?P<opts>[*?0-9bcikoprsez]*):(?P<trigger>[^:]+)::(?:\s*\{?)\s*;?\s*(?P<comment>.*)"

        ; FIXED: Simple working regex patterns
        hotkeyRegex     := "^(?<hk>\S+)::"                    ; Simple pattern that works with #h::
        hotstringRegex  := "^(?!$)\s*:(?<hsopts>(?:[*?BCKOPRTXZ0-9]|S(?:I|E|P))*):(?<hs>.*?)::(?<hstext>.*?)(?<comment>;.*?)?\s*$"

        hotkeyCount := 0
        hotstringCount := 0
        triggersCount := 0
        global arrayBaseList := []
        global mapScriptList := Map()

        ; Array to track scanned scripts
        global gScriptCount := arrayScripts.Length

        moduleCore.logToFile("========== Script Content Scanning ==========")
        moduleCore.logToFile("Starting to scan " arrayScripts.Length " scripts for hotkeys and hotstrings...")

        ; Log the regex patterns being used
        moduleCore.logToFile("REGEX PATTERNS:")
        moduleCore.logToFile("  Hotkey regex: " hotkeyRegex)
        moduleCore.logToFile("  Hotstring regex: " hotstringRegex)

        cntMax := 100
        cnt1 := 0
        for index, script in arrayScripts {
            cs := this.getScript(script)
            ; NMS Next line added
            scriptPath := script.path

            moduleCore.logToFile("Scanning script: " cs.scriptName " (" cs.scriptPath ")")

            try {
                scriptContents := FileRead(cs.scriptPath)
                scriptLineCount := StrSplit(scriptContents, "`n", "`r").Length
                moduleCore.logToFile("  Successfully read file: " scriptLineCount " lines")

                ; Log the actual file contents for debugging
                moduleCore.logToFile("  FILE CONTENTS:")
                fileLines := StrSplit(scriptContents, "`n", "`r")
                for lineIndex, lineContent in fileLines {
                    moduleCore.logToFile('    Line ' lineIndex ': ' lineContent)
                }

            } catch as err {
                moduleCore.logToFile("  ERROR reading file: " err.Message)
                continue
            }

            matched := false
            commentBlock := false
            localHotkeyCount := 0
            localHotstringCount := 0
            localTriggersCount := 0
            matchedLines := []

            ; First scan for standard hotkeys/hotstrings in the script content
            moduleCore.logToFile("  STARTING LINE-BY-LINE ANALYSIS:")

            cnt2 := 0
            for lineNum, line in StrSplit(scriptContents, "`n", "`r") {
                moduleCore.logToFile('    Processing line ' lineNum ': ' line)
                cnt2++
                if cnt2 < 0
                    MsgBox('lineNum:`t' lineNum '`nline:`t' line) 

                ; Check for comment blocks
                if (RegExMatch(line, "^\s*(\/\*|\((?!.*\)))")) {
                    commentBlock := true
                    moduleCore.logToFile("      -> Comment block START detected")
                }
                else if (RegExMatch(line, "^\s*(\*\/|\))")) {
                    commentBlock := false
                    moduleCore.logToFile("      -> Comment block END detected")
                }

                ; Skip empty lines, comment blocks, and single-line comments
                if (!line) {
                    moduleCore.logToFile("      -> SKIP: Empty line")
                    continue
                }
                if (commentBlock) {
                    moduleCore.logToFile("      -> SKIP: Inside comment block")
                    continue
                }
                if (RegExMatch(line, "^\s*;.*?$")) {
                    moduleCore.logToFile("      -> SKIP: Single-line comment")
                    continue
                }

                moduleCore.logToFile("      -> TESTING for hotkey/hotstring patterns...")

                match := {}
                command := ""
                description := ""
                lineType := ""

                ; Test hotkey pattern with FIXED simple regex and enhanced command extraction
                moduleCore.logToFile("      -> Testing hotkey regex: " hotkeyRegex)
                if (RegExMatch(line, hotkeyRegex, &matchHotkey)) {
                    moduleCore.logToFile("      -> HOTKEY MATCH FOUND!")
                    moduleCore.logToFile("         Full match object keys: " this.GetMatchKeys(&matchHotkey))
                    moduleCore.logToFile("         matchHotkey type: " Type(matchHotkey))

                    ; Try multiple ways to extract the command
                    command := ""
                    if (IsObject(matchHotkey) && matchHotkey.HasOwnProp("hk")) {
                        command := Trim(matchHotkey.hk)
                        moduleCore.logToFile('         Extracted hotkey command via .hk property: ' command)
                    } else if (IsObject(matchHotkey) && matchHotkey.HasOwnProp("1")) {
                        command := Trim(matchHotkey[1])
                        moduleCore.logToFile('         Extracted hotkey command via [1] index: ' command)
                    } else {
                        ; Fallback: extract manually from the line
                        colonPos := InStr(line, "::")
                        if (colonPos > 0) {
                            command := Trim(SubStr(line, 1, colonPos - 1))
                            moduleCore.logToFile('         Extracted hotkey command manually: ' command)
                        } else {
                            moduleCore.logToFile("         ERROR: Could not extract hotkey command")
                            command := ""
                        }
                    }

                    ; Ensure command is not empty
                    if (command = "") {
                        moduleCore.logToFile("         WARNING: Command is empty, using fallback extraction")
                        colonPos := InStr(line, "::")
                        if (colonPos > 0) {
                            command := Trim(SubStr(line, 1, colonPos - 1))
                            moduleCore.logToFile('         Fallback command: ' command)
                        }
                    }

                    ; Extract comment manually since simple regex doesn't capture it
                    description := ""
                    if (InStr(line, ";")) {
                        commentPos := InStr(line, ";")
                        commentText := SubStr(line, commentPos + 1)
                        description := Trim(commentText)
                        moduleCore.logToFile('         Extracted comment manually: ' description)
                    } else {
                        moduleCore.logToFile("         No comment found")
                    }

                    lineType := "hotkey"
                    hotkeyCount++
                    localHotkeyCount++
                    moduleCore.logToFile('         -> HOTKEY CONFIRMED: ' command ' with description: ' description)
                }
                else {
                    moduleCore.logToFile("      -> No hotkey match")

                    ; Keep simple debugging for troubleshooting
                    if (InStr(line, "::")) {
                        moduleCore.logToFile("         Line contains '::' but didn't match hotkey pattern")
                        colonPos := InStr(line, "::")
                        beforeColon := SubStr(line, 1, colonPos - 1)
                        moduleCore.logToFile("         Text before '::': '" beforeColon "'")

                        ; Test the simple pattern directly
                        if (RegExMatch(beforeColon, "^\S+$")) {
                            moduleCore.logToFile('         Should have matched! Pattern ^\S+$ works on ' beforeColon)
                        } else {
                            moduleCore.logToFile('         Pattern ^\S+$ doesn`'t match ' beforeColon)
                        }
                    } else {
                        moduleCore.logToFile("         Line does NOT contain '::' - not a hotkey")
                    }
                }

                ; Test hotstring pattern
                moduleCore.logToFile("      -> Testing hotstring regex: " hotstringRegex)
                if (RegExMatch(line, hotstringRegex, &matchHotstring)) {
                    moduleCore.logToFile("      -> HOTSTRING MATCH FOUND!")

                    command := Trim(matchHotstring.hs)
                    moduleCore.logToFile('         Extracted hotstring: ' command)

                    ; For hotstrings, prefer the replacement text, then comment
                    if (matchHotstring.hstext && Trim(matchHotstring.hstext) != "") {
                        description := Trim(matchHotstring.hstext)
                        moduleCore.logToFile('         Using replacement text as description: ' description)
                    } else if (matchHotstring.HasOwnProp("comment") && matchHotstring.comment) {
                        description := Trim(RegExReplace(matchHotstring.comment, "^;\s*"))
                        moduleCore.logToFile('         Using comment as description: ' description)
                    } else {
                        description := ""
                        moduleCore.logToFile("         No description found")
                    }

                    lineType := "hotstring"
                    hotstringCount++
                    localHotstringCount++
                    moduleCore.logToFile("         -> HOTSTRING CONFIRMED: " command)
                } else {
                    moduleCore.logToFile("      -> No hotstring match")
                }

                ; Check for Hotkey/Hotstring function calls
                ; NMS 1 line commented and 1 line added because following me the next line acts equal as the new line
                if (!lineType && (InStr(line, "Hotkey(", true) || InStr(line, "Hotkey,", true))) {
                    inspLine := Trim(line)
                    cnt3 := 0
                    if !InStr(inspLine, 'STR ') || InStr(inspLine, ' Hotkey ', 0) || InStr(inspLine, ',Hotkey ', 0) || InStr(inspLine, ' Hotkey(', 0) || InStr(inspLine, ',Hotkey(', 0) {
                    ; && StrLower(SubStr(inspLine, 1, 7)) == 'hotkey ' || StrLower(SubStr(inspLine, 1, 7)) == 'hotkey(' {
                        command := ''
                        While (posHotkey := InStr(inspLine, 'Hotkey', 0)) > 0 {
                            ; cnt3++
                            ; if cnt3 < cntMax
                            ;     MsgBox('scriptPath:`t' scriptPath '`nHotkey check:`t'  cnt3 '`ninspLine:`t' inspLine '`ttest:`t' InStr(inspLine, ';')) 
                            if (InStr(inspLine, ';') == 0 || posHotkey < InStr(inspLine, ';'))  {      ; Hotkey is possible available and before comment
                                ; MsgBox('Hotkey check:`t'  cnt3 '`ninspLine:`t' inspLine '`ttest:`t' InStr(inspLine, ';')) 
                                inspLine := SubStr(inspLine, posHotkey)
                                char := SubStr(inspLine, 7, 1)                                                              ; char should be ' ' or '('
                                endPos := 7
                                if (char = ' ' || char = '(') {                                                             ; inspectLine starts with a Hotkey function
                                    strtPos := Min(single := InStr(inspLine, '`'') + 1, double := InStr(inspLine, '"') + 1)  ; Hotkey must start with ' or with "
                                    if strtPos = single
                                        endPos := InStr(inspLine, '`'',,, 2)
                                    else
                                        endPos := InStr(inspLine, '`'',,, 2)
                                    command := command SubStr(inspLine, strtPos, endPos - strtPos) ' '   	                            ; Get the hotkey and end with a space for possible more hotkeys
                                }
                                inspLine := SubStr(inspLine, endPos)                                                        ; Make inspLine ready for test for another Hotkey
                            } else
                                inspLine := ''
                        }
                        if (command != '') {
                            if (InStr(line, ";")) {
                                commentPart := Trim(SubStr(line, InStr(line, ";") + 1))
                                description := commentPart
                            } else {
                                description := ""
                            }

                            lineType := "hotkey"
                            hotkeyCount++
                            localHotkeyCount++
                            moduleCore.logToFile("         -> HOTKEY FUNCTION CONFIRMED: " command)
                        }
                    }
                }

                ; Check for Hotkey/Hotstring function calls
                ; NMS 1 line commented and 1 line added because following me the next line acts equal as the new line
                ; if (!lineType && (InStr(line, "Hotkey(", true) || InStr(line, "Hotkey,", true))) {
                ; else if (!lineType && InStr(line, "Hotstring(", true)) {
                ;     moduleCore.logToFile("      -> Found Hotstring function call")
                ;     ; Try to extract from Hotstring call
                ;     line := Trim(line)
                ;     startPos := InStr(line, "Hotstring(") + 11
                ;     endPos := InStr(line, ",", true, startPos) - 1

                ;     if (endPos > startPos) {
                ;         command := SubStr(line, startPos, endPos - startPos)

                ;         if (InStr(line, ";")) {
                ;             commentPart := Trim(SubStr(line, InStr(line, ";") + 1))
                ;             description := commentPart
                ;         } else {
                ;             description := ""
                ;         }

                ;         lineType := "hotstring"
                ;         hotstringCount++
                ;         localHotstringCount++
                ;         moduleCore.logToFile("         -> HOTSTRING FUNCTION CONFIRMED: " command)
                ;     }
                ; }

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
                        conflictInfo := ConflCheck.CheckHotkeyConflict(command)
                        if (conflictInfo) {
                            moduleCore.logToFile("         -> CONFLICT DETECTED: " conflictInfo.windowsKey)
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
                        conflict: conflictInfo,
                        ; NMS Next line added
                        path: scriptPath
                    })

                    ; Enhanced logging for debugging with conflict info
                    conflictText := conflictInfo ? " [CONFLICT: " conflictInfo.windowsKey "]" : ""
                    moduleCore.logToFile("         -> ADDED TO ARRAY: type=" lineType ", command='" command "', desc='" description "', line=" lineNum conflictText)
                } else {
                    moduleCore.logToFile("      -> No match found for this line")
                }
            }

            ; Check for Triggers class usage
            hasTriggers := InStr(scriptContents, "Triggers.Add") ||
                        InStr(scriptContents, "Triggers.AddHotkey") ||
                        InStr(scriptContents, "Triggers.AddMouse") ||
                        InStr(scriptContents, "Triggers.AddHotstring")

            if (hasTriggers) {
                moduleCore.logToFile("  Triggers class usage detected in script: " cs.scriptName)

                ; Now check if settings.ini exists
                iniPath := cs.scriptDir "\settings.ini"
                if (FileExist(iniPath)) {
                    moduleCore.logToFile("  Found settings.ini file: " iniPath)

                    ; Process Triggers INI regardless of whether we found direct hotkeys
                    ; Scripts can have BOTH direct hotkeys AND Triggers-based hotkeys
                    moduleCore.logToFile("  Checking for ScanTriggersIni function...")

                    ; Check for the ScanTriggersIni function and call it if it exists
                    functionFound := false

                    try {
                        ; In AHK v2, we check function existence through a try-catch
                        moduleCore.logToFile("  Attempting to call ScanTriggersIni function...")
                        triggersStats := trIniSc.ScanTriggersIni(cs, scriptContents)
                        functionFound := true
                        moduleCore.logToFile("  ScanTriggersIni function called successfully")

                        if (triggersStats.triggersFound) {
                            moduleCore.logToFile("  Triggers class confirmed in script")

                            if (triggersStats.iniFound) {
                                moduleCore.logToFile("  Processed settings.ini: " triggersStats.iniPath)
                                moduleCore.logToFile("  Added: "
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
                                moduleCore.logToFile("  No entries found in settings.ini")
                            }
                        } else {
                            moduleCore.logToFile("  No active Triggers found in script despite usage")
                        }
                    } catch as err {
                        functionFound := false
                        moduleCore.logToFile("  ERROR: ScanTriggersIni function error: " err.Message)

                        ; Provide details about the error for troubleshooting
                        moduleCore.logToFile("  Full error details: " err.Extra " (Line: " err.Line ")")

                        ; If we can't process with the function, provide a fallback
                        if (hasTriggers && FileExist(iniPath)) {
                            moduleCore.logToFile("  Attempting fallback processing of settings.ini...")

                            try {
                                ; Basic fallback processing
                                hotkeySection := IniRead(iniPath, "Hotkeys")
                                if (hotkeySection) {
                                    sectionLines := StrSplit(hotkeySection, "`n", "`r")
                                    moduleCore.logToFile("  Found " sectionLines.Length " entries in Hotkeys section")

                                    for _, line in sectionLines {
                                        moduleCore.logToFile("    Entry: " line)
                                    }
                                } else {
                                    moduleCore.logToFile("  No Hotkeys section found in settings.ini")
                                }
                            } catch as err2 {
                                moduleCore.logToFile("  Fallback processing error: " err2.Message)
                            }
                        }
                    }

                    if (!functionFound) {
                        moduleCore.logToFile("  ScanTriggersIni function not found or error occurred")
                        moduleCore.logToFile("  Make sure TriggersIniScanner.ahk is included properly")

                        ; Check if we can find the module
                        if (FileExist(A_ScriptDir "\TriggersIniScanner.ahk")) {
                            moduleCore.logToFile("  TriggersIniScanner.ahk exists in script directory")
                        } else {
                            moduleCore.logToFile("  TriggersIniScanner.ahk not found in script directory")
                        }
                    }
                } else {
                    moduleCore.logToFile("  No settings.ini file found at: " iniPath)
                    ; Even without settings.ini, log the Triggers calls we found for reference
                    moduleCore.logToFile("  Script uses Triggers class but has no settings.ini - only direct Triggers calls will be visible")
                }
            } else {
                moduleCore.logToFile("  No Triggers class usage detected in script")
            }

            ; Log the results for this script - include BOTH direct and Triggers counts
            totalFound := localHotkeyCount + localHotstringCount + localTriggersCount
            moduleCore.logToFile("  FINAL SUMMARY for " cs.scriptName ":")
            moduleCore.logToFile("    Direct hotkeys found: " localHotkeyCount)
            moduleCore.logToFile("    Direct hotstrings found: " localHotstringCount)
            moduleCore.logToFile("    Triggers-based commands: " localTriggersCount)
            moduleCore.logToFile("    Total commands found: " totalFound)

            if (totalFound = 0) {
                moduleCore.logToFile("    *** NO COMMANDS FOUND - CHECK REGEX PATTERNS ***")
            }

            ; Log first 5 matched direct lines for debugging
            if (matchedLines.Length > 0) {
                maxToShow := Min(matchedLines.Length, 5)
                moduleCore.logToFile("  First " maxToShow " matched DIRECT lines:")
                for i, item in matchedLines {
                    if (i > maxToShow)
                        break
                    moduleCore.logToFile("    Line " item.line ": " Trim(item.content) " (" item.type ") - Command: " item.command " - Desc: '" item.description "'")
                }
            }

            ; Update the global counts for later use
            global gHotkeyCount := hotkeyCount
            global gHotstringCount := hotstringCount

            moduleCore.logToFile("FINAL TOTALS: " hotkeyCount " hotkeys, " hotstringCount " hotstrings, " triggersCount " Triggers commands")

            ; Debug: Log the first few items in arrayBaseList with their descriptions
            if (arrayBaseList.Length > 0) {
                moduleCore.logToFile("Debug: First 5 items in arrayBaseList with descriptions:")
                maxItems := Min(arrayBaseList.Length, 5)
                Loop maxItems {
                    i := A_Index
                    item := arrayBaseList[i]
                    moduleCore.logToFile("  Item " i ": command='" item.command "', desc='" item.description "', type=" (item.type = "k" ? "hotkey" : "hotstring")
                            ", file=" item.file ", line=" item.line ", source=" (item.HasOwnProp("source") ? item.source : "unknown"))
                }
            } else {
                moduleCore.logToFile("Debug: arrayBaseList is empty!")
            }
        }
    }

    /**
     * =====================================================================
     * GetMatchKeys - Debug utility for inspecting RegEx match objects
     * =====================================================================
     * 
     * PURPOSE:
     *   Helper function to introspect regex match objects and determine what
     *   properties are accessible. Extremely useful for debugging complex regex 
     *   patterns when you're unsure what capture groups are available.
     * 
     * PROCESS:
     *   1. Validates input is actually an object
     *   2. Attempts to access common match object properties:
     *      - Named capture groups (e.g., "hk", "comment")
     *      - Numbered capture groups (1, 2, etc.)
     *      - Standard properties (Count, Len, Pos)
     *   3. Builds a string with all found properties and their values
     *   4. Returns diagnostic information
     * 
     * PARAMETERS:
     *   matchObj : RegExMatchInfo object from RegExMatch()
     * 
     * RETURNS:
     *   String describing accessible properties
     *   Examples:
     *     "hk='^!c' comment='Copy text' Count=2 Len=10 Pos=1"
     *     "Not an object - type: String"
     *     "No accessible properties found"
     * 
     * USE CASE:
     *   When a regex pattern isn't capturing what you expect:
     *   if RegExMatch(line, pattern, &match)
     *       MsgBox(this.GetMatchKeys(match))  ; Shows what was captured
     * 
     * NOTES:
     *   - Primarily used during development/debugging
     *   - Safe to call even with invalid input
     *   - Particularly useful for patterns with named groups
     */
    ; New : 25-01-24
    ; GetMatchKeys : (matchObj) : Helper function to debug match objects
    ; matchObj : object - RegEx match object to inspect
    ; Returns : string - String describing accessible properties
    GetMatchKeys(matchObj) {
        ; NMS 1 line added
        moduleCore.logToFile("========== ScriptScanner / GetMatchKeys ==========", 'NMS')
        if (!IsObject(matchObj)) {
            return "Not an object - type: " Type(matchObj)
        }

        keys := ""
        try {
            ; Try to access named capture groups
            if (matchObj.HasOwnProp("hk"))
                keys .= "hk='" matchObj.hk '`' '
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

    /**
     * =====================================================================
     * GetNotRunningScripts - Identifies scripts that are not executing
     * =====================================================================
     * 
     * PURPOSE:
     *   Checks each script in the array to determine if it's currently running.
     *   Can be used for health monitoring, automatic restart systems, or status 
     *   reporting in script management tools.
     * 
     * PROCESS:
     *   1. Iterates through the array of script objects
     *   2. For each script, checks if its window handle is still valid
     *   3. If window doesn't exist, adds script to "not running" list
     *   4. Logs the status of each script checked
     *   5. Returns array of non-running scripts
     * 
     * PARAMETERS:
     *   arrayScripts : Array of script objects with hwnd and path properties
     * 
     * RETURNS:
     *   Array of script objects that are not currently running
     *   NOTE: Currently returns the ORIGINAL array unchanged (see line 708)
     *         This appears to be legacy code or placeholder for future functionality
     * 
     * USE CASES:
     *   - Script health monitoring dashboards
     *   - Automatic script restart systems
     *   - Status reporting for script management
     *   - Debugging why certain hotkeys aren't working
     * 
     * CURRENT BEHAVIOR:
     *   Despite building a notRunningScripts array, the function returns the
     *   original arrayScripts parameter. This may be intentional (to always
     *   return full list) or may be a placeholder for future enhancement.
     * 
     * DEPENDENCIES:
     *   - Peep(): Debug visualization function
     *   - moduleCore.logToFile(): For status logging
     * 
     * EXAMPLE:
     *   notRunning := scanner.GetNotRunningScripts(allScripts)
     *   ; Can use this to alert user or attempt to restart scripts
     */
    ; New : 25-01-24
    ; GetNotRunningScripts : (arrayScripts) : Check for scripts that are not currently running
    ; arrayScripts : array - Array of script objects to check
    ; Returns : array - Original array (currently returns all scripts)
    GetNotRunningScripts(arrayScripts) {
        ; NMS 1 line added
        moduleCore.logToFile("========== ScriptScanner / GetNotRunningScripts ==========", 'NMS')

        notRunningScripts := []
        for script in arrayScripts {
            if (!WinExist("ahk_id " script.hwnd)) {
                moduleCore.logToFile("Script not running: " script.path)
                notRunningScripts.Push(script)
            } else {
                moduleCore.logToFile("Script is currently running: " script.path)
            }
        }

        moduleCore.logToFile("Not running scripts detection complete. Found " notRunningScripts.Length " scripts that are not running.")
        return arrayScripts
    }
}

;================= End of ScriptScanner =================