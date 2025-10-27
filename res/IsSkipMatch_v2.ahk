;================= IsSkipMatch v1.0.0 =================
; Function to enhance the script skipping functionality in AHKHotkeyStringLookup -
; provides exact matching for both filenames and paths with detailed skip reasons.

#Requires AutoHotkey v2.0.2+
; NMS Next line added
#SingleInstance Force

; NMS Next 6 lines added
; Retrieve Scripts to be skipped
skipScripts := StrSplit(FileRead('Skip_Scripts.ini'), ',')
arraySkipScriptList := []
Loop skipScripts.Length
    if !InStr(skipScripts[A_Index], ';')
        arraySkipScriptList.Push(SubStr(skipScripts[A_Index],2))

Class IsSkipMatch {
    ; This class provides a method to check if a script should be skipped based on
    ; an exact match against a predefined skip list.

    ; This function can be integrated directly into ScriptScanner.ahk

    ; New : 25-01-24
    ; IsSkipMatch : (scriptName, scriptPath, arraySkipList) : Check if a script should be skipped
    ; scriptName : string - Name of the script file
    ; scriptPath : string - Full path to the script file
    ; arraySkipList : array - Array of script names/paths to skip
    ; Returns : object - Object with result (bool), reason (string), and matchType (string)
    IsSkipMatch(scriptName, scriptPath, arraySkipList) {
        ; First check exact filename matches
        for skipItem in arraySkipList {
            ; Check if the skip item is a full path
            if (InStr(skipItem, '\')) {
                ; Compare full paths for exact match
                if (scriptPath = skipItem) {
                    return {
                        result: true,
                        reason: 'Exact path match: ' skipItem,
                        matchType: 'path'
                    }
                }
            }
            ; Check filename match
            else if (scriptName = skipItem) {
                return {
                    result: true,
                    reason: 'Exact filename match: ' skipItem,
                    matchType: 'filename'
                }
            }
        }

        ; If we reach here, script should not be skipped
        return {
            result: false,
            reason: 'No match found in skip list',
            matchType: 'none'
        }
    }

    ; This function can be used to replace the IsScriptToBeSkipped() function
    ; Example usage:
    ;
    ; matchResult := IsSkipMatch(scriptName, scriptPath, arraySkipScriptList)
    ; if (matchResult.result) {
    ;     logToFile('  SKIPPING: ' matchResult.reason)
    ;     continue
    ; }
}
;================= End of IsSkipMatch =================
