;================= ScriptEditor v1.0.0 =================
; Script editing functionality for AHKHotkeyStringLookup - handles opening AutoHotkey
; scripts in appropriate editors with line number support and editor detection.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

#Include CoreModule_v2.ahk
moduleCore := CoreModule()

; #Include ScriptScanner.ahk2
; scriptSc := ScriptScanner()

; Explicitly declare global functions and variables used from other modules
; NMS Next two lines commented
; global moduleCore.logToFile
; global logMsgBox
global objScript

Class ScriptEditor {
    ; New : 25-01-24
    ; OpenScript : (path, name, lineNumber) : Open script with appropriate editor
    ; path : string - Full path to script file
    ; name : string - Script file name
    ; lineNumber : int - Line number to jump to
    OpenScript(path, name, lineNumber) {
        ; NMS 1 line added
        moduleCore.logToFile("============= ScriptEditor / OpenScript ===============", 'NMS')
        try {
            moduleCore.logToFile("Opening script: " path " at line " lineNumber)

            ; Use enhanced editor open function
            result := this.OpenWithDefaultEditor(path, lineNumber)

            if (result) {
                moduleCore.logToFile("Successfully opened script in default editor")
            } else {
                moduleCore.logToFile("Failed to open script with default editor, falling back to simple Edit")
                try {
                    Run "Edit " path
                    moduleCore.logToFile("Opened with simple Edit command")
                } catch as err {
                    moduleCore.logToFile("Error with fallback Edit command: " err.Message)
                    MsgBox("Error opening script: " err.Message, "Error", "0x10")
                    return
                }
            }

            moduleCore.logMsgBox("Opening " name " at line " lineNumber, objScript.name, "0x40")
        } catch as err {
            moduleCore.logToFile("Error opening script: " err.Message)
            MsgBox("Error opening script: " err.Message, "Error", "0x10")
        }
    }

    ; New : 25-01-24
    ; OpenWithDefaultEditor : (scriptPath, lineNum) : Find and open the default editor
    ; scriptPath : string - Full path to script file
    ; lineNum : int - Line number to jump to
    ; Returns : bool - True on success, False on failure
    OpenWithDefaultEditor(scriptPath, lineNum) {
        ; NMS 1 line added
        moduleCore.logToFile("============= ScriptEditor / OpenWithDefaultEditor ===============", 'NMS')
        ; Ensure the script exists
        if !FileExist(scriptPath) {
            moduleCore.logToFile("Script file not found: " scriptPath)
            return false
        }

        ; Find the default editor from registry
        defaultApp := ""

        try {
            openWithKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ahk\OpenWithList"
            mruList := RegRead(openWithKey, "MRUList")

            if mruList {
                defaultLetter := SubStr(mruList, 1, 1)
                defaultApp := RegRead(openWithKey, defaultLetter)
                moduleCore.logToFile("Found default editor from registry: " defaultApp)
            }
        } catch Error as e {
            moduleCore.logToFile("Error reading registry: " e.Message)
            ; Continue if registry read fails
        }

        ; If we found a default app, try to find its path
        if defaultApp {
            editorPath := this.FindEditor(defaultApp)

            if editorPath {
                ; Determine editor type
                try {
                    SplitPath(editorPath, &editorName)
                    editorName := StrLower(editorName)
                    moduleCore.logToFile("Found editor: " editorName " at " editorPath)

                    ; Set command line based on editor type
                    if InStr(editorName, "scite") {
                        commandLine := '"' editorPath '" "' scriptPath '" -goto:' lineNum
                    }
                    else if InStr(editorName, "code") {
                        commandLine := '"' editorPath '" -g "' scriptPath ':' lineNum '"'
                    }
                    else if InStr(editorName, "notepad++") {
                        commandLine := '"' editorPath '" "' scriptPath '" -n' lineNum
                    }
                    else if InStr(editorName, "sublime_text") {
                        commandLine := '"' editorPath '" "' scriptPath ':' lineNum '"'
                    }
                    else {
                        commandLine := '"' editorPath '" "' scriptPath '"'
                    }

                    moduleCore.logToFile("Launching editor with command: " commandLine)

                    ; Try to run the editor
                    try {
                        Run(commandLine)
                        return true
                    } catch Error as e {
                        moduleCore.logToFile("Error running editor: " e.Message)
                        ; Continue if run fails
                    }
                } catch Error as e {
                    moduleCore.logToFile("Error preparing editor command: " e.Message)
                }
            }
        }

        ; Fallback to SciTE if default editor not found
        scitePath := "C:\Program Files\AutoHotkey\SciTE\SciTE.exe"
        if FileExist(scitePath) {
            try {
                moduleCore.logToFile("Fallback to SciTE: " scitePath)
                Run('"' scitePath '" "' scriptPath '" -goto:' lineNum)
                return true
            } catch Error as e {
                moduleCore.logToFile("Error running SciTE: " e.Message)
                ; Continue if SciTE run fails
            }
        }

        ; Last resort - Notepad
        try {
            moduleCore.logToFile("Last resort - using Notepad")
            Run("notepad.exe " scriptPath)
            return true
        } catch Error as e {
            moduleCore.logToFile("Error running Notepad: " e.Message)
            return false
        }
    }

    ; New : 25-01-24
    ; FindEditor : (editorName) : Find an editor executable
    ; editorName : string - Editor executable name
    ; Returns : string - Full path to editor or empty string if not found
    FindEditor(editorName) {
        ; NMS 1 line added
        moduleCore.logToFile("============= ScriptEditor / FindEditor ===============", 'NMS')
        moduleCore.logToFile("Searching for editor executable: " editorName)

        ; Special case for VS Code
        if (editorName = "Code.exe") {
            vsCodePath := "C:\Users\" A_UserName "\AppData\Local\Programs\Microsoft VS Code\Code.exe"
            if FileExist(vsCodePath) {
                moduleCore.logToFile("Found VS Code at: " vsCodePath)
                return vsCodePath
            }
        }

        ; For SciTE
        if (editorName = "SciTE.exe") {
            scitePath := "C:\Program Files\AutoHotkey\SciTE\SciTE.exe"
            if FileExist(scitePath) {
                moduleCore.logToFile("Found SciTE at: " scitePath)
                return scitePath
            }
        }

        ; Try WHERE command
        try {
            moduleCore.logToFile("Trying WHERE command to locate " editorName)
            whereCmd := ComObject("WScript.Shell").Exec("where " editorName)
            whereResult := whereCmd.StdOut.ReadAll()

            if whereResult {
                lines := StrSplit(whereResult, "`n", "`r")
                if lines.Length > 0 {
                    path := Trim(lines[1])
                    if FileExist(path) {
                        moduleCore.logToFile("Found using WHERE: " path)
                        return path
                    }
                }
            }
        } catch Error as e {
            moduleCore.logToFile("WHERE command failed: " e.Message)
            ; Continue if WHERE fails
        }

        ; Check common locations
        searchLocations := [
            A_AppData "\Local\Programs\Microsoft VS Code\" editorName,
            A_AppData "\Local\Programs\" editorName,
            A_AppData "\Local\" editorName,
            A_ProgramFiles "\" editorName,
            A_ProgramFiles " (x86)\" editorName,
            A_WinDir "\system32\" editorName,
            A_WinDir "\" editorName
        ]

        for path in searchLocations {
            if FileExist(path) {
                moduleCore.logToFile("Found in common location: " path)
                return path
            }
        }

        moduleCore.logToFile("Editor executable not found: " editorName)
        ; Not found
        return ""
    }
}
;================= End of ScriptEditor =================
