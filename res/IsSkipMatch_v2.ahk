;================= IsSkipMatch v1.0.0 =================
; Function to enhance the script skipping functionality in AHKHotkeyStringLookup -
; provides exact matching for both filenames and paths with detailed skip reasons.

#Requires AutoHotkey v2.0.2+

; This function can be integrated directly into ScriptScanner.ahk

; Enhanced function to check if a script should be skipped
; Uses exact matching for both filenames and paths
IsSkipMatch(scriptName, scriptPath, arraySkipList) {
    ; First check exact filename matches
    for skipItem in arraySkipList {
        ; Check if the skip item is a full path
        if (InStr(skipItem, "\")) {
            ; Compare full paths for exact match
            if (scriptPath = skipItem) {
                return {
                    result: true,
                    reason: "Exact path match: " skipItem,
                    matchType: "path"
                }
            }
        }
        ; Check filename match
        else if (scriptName = skipItem) {
            return {
                result: true,
                reason: "Exact filename match: " skipItem,
                matchType: "filename"
            }
        }
    }

    ; If we reach here, script should not be skipped
    return {
        result: false,
        reason: "No match found in skip list",
        matchType: "none"
    }
}

; This function can be used to replace the IsScriptToBeSkipped() function
; Example usage:
;
; matchResult := IsSkipMatch(scriptName, scriptPath, arraySkipScriptList)
; if (matchResult.result) {
;     logToFile("  SKIPPING: " matchResult.reason)
;     continue
; }

;================= End of IsSkipMatch =================