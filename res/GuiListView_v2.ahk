;================= GuiListView v1.0.0 =================
; ListView functionality - manages the main ListView control with configurable
; row coloring, populates data, and handles color application based on conflict status.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

; Declare global variables used from other modules
global g_mainListView
global g_lvColors
global logToFile
global logDebug
global DEBUG_ENABLED
global GetConflictStatusText

; Declare global color configuration variables (set in main script)
global NORMAL_BG_COLOR
global NORMAL_TEXT_COLOR
global CONFLICT_BG_COLOR
global CONFLICT_TEXT_COLOR

; Initialize g_lvColors to prevent unassigned variable errors
if (!IsSet(g_lvColors)) {
    g_lvColors := ""
}

; Function to safely get control properties with multiple methods
GetControlProperty(control, propertyName) {
    if (!IsObject(control)) {
        return ""
    }
    
    ; Method 1: Direct property access with HasOwnProp
    if (control.HasOwnProp(propertyName)) {
        try {
            return control.%propertyName%
        } catch {
            ; Continue to next method
        }
    }
    
    ; Method 2: Try without HasOwnProp check (some AHK versions)
    try {
        return control.%propertyName%
    } catch {
        ; Continue to next method
    }
    
    ; Method 3: For Hwnd specifically, try alternative methods
    if (propertyName = "Hwnd") {
        try {
            return control.HWND
        } catch {
            ; Continue
        }
        
        try {
            return control.hwnd
        } catch {
            ; Continue
        }
    }
    
    ; Method 4: For Type specifically
    if (propertyName = "Type") {
        try {
            return control.ClassNN
        } catch {
            ; Continue
        }
    }
    
    return ""  ; Property not found
}

; Function to create and initialize LV_Colors for the ListView
InitializeListViewColors(listView) {
    global g_lvColors

    ; Always log the basic initialization
    logToFile("Initializing ListView colors...")
    
    ; Enhanced debug logging only if debug enabled
    if (DEBUG_ENABLED) {
        logDebug("=== DETAILED LISTVIEW COLOR INITIALIZATION ===")
        logDebug("AutoHotkey version: " . A_AhkVersion)
        logDebug("Parameter received - Type: " . Type(listView))
        logDebug("Parameter received - Is Object: " . (IsObject(listView) ? "YES" : "NO"))
        
        ; Log color configuration
        logDebug("Color configuration:")
        logDebug("  NORMAL_BG_COLOR: 0x" . Format("{:06X}", NORMAL_BG_COLOR))
        logDebug("  NORMAL_TEXT_COLOR: 0x" . Format("{:06X}", NORMAL_TEXT_COLOR))
        logDebug("  CONFLICT_BG_COLOR: 0x" . Format("{:06X}", CONFLICT_BG_COLOR))
        logDebug("  CONFLICT_TEXT_COLOR: 0x" . Format("{:06X}", CONFLICT_TEXT_COLOR))
        
        if (IsObject(listView)) {
            logDebug("Testing property access methods...")
            
            ; Test Hwnd property with all methods
            hwndValue := GetControlProperty(listView, "Hwnd")
            logDebug("Hwnd via GetControlProperty: " . (hwndValue ? hwndValue : "NOT FOUND"))
            
            ; Test Type property
            typeValue := GetControlProperty(listView, "Type")
            logDebug("Type via GetControlProperty: " . (typeValue ? typeValue : "NOT FOUND"))
        }
    }

    ; Validate ListView control
    if (!IsObject(listView)) {
        logToFile("ERROR: Invalid ListView control - not an object")
        return false
    }
    
    ; Get Hwnd using our safe method
    hwndValue := GetControlProperty(listView, "Hwnd")
    if (!hwndValue) {
        logToFile("ERROR: Cannot get Hwnd property from ListView control")
        if (DEBUG_ENABLED) {
            logDebug("This suggests a version compatibility issue with AutoHotkey " . A_AhkVersion)
        }
        return false
    }
    
    ; Validate that it's actually a ListView
    typeValue := GetControlProperty(listView, "Type")
    if (typeValue && typeValue != "ListView") {
        logToFile("ERROR: Control is not a ListView, it's a " . typeValue)
        return false
    }

    try {
        logDebug("Attempting to create LV_Colors instance with Hwnd: " . hwndValue)

        ; Create LV_Colors with the ListView control object
        g_lvColors := LV_Colors(listView)

        if (DEBUG_ENABLED) {
            logDebug("LV_Colors constructor completed")
            logDebug("g_lvColors type: " . Type(g_lvColors))
            logDebug("g_lvColors is object: " . (IsObject(g_lvColors) ? "YES" : "NO"))
        }

        if (!IsObject(g_lvColors)) {
            logToFile("ERROR: Failed to create LV_Colors instance")
            return false
        }

        ; Enable colors
        logDebug("Enabling colors with ShowColors(true)...")
        g_lvColors.ShowColors(true)

        logToFile("✓ ListView colors initialized successfully")
        return true

    } catch as err {
        logToFile("CRITICAL ERROR: Exception in LV_Colors creation: " . err.Message)
        
        if (DEBUG_ENABLED) {
            logDebug("Detailed error information:")
            logDebug("  Error message: " . err.Message)
            logDebug("  Error extra: " . err.Extra)
            logDebug("  Error line: " . err.Line)
            logDebug("  Error file: " . err.File)
            logDebug("  AutoHotkey version: " . A_AhkVersion)
        }
        
        g_lvColors := ""
        return false
    }
}

; Function to apply colors to ListView rows based on conflict status
ApplyRowColors(items) {
    global g_lvColors

    logToFile("Applying row colors to " . items.Length . " items...")
    
    if (DEBUG_ENABLED) {
        logDebug("=== DETAILED ROW COLOR APPLICATION ===")
        logDebug("g_lvColors type: " . Type(g_lvColors))
        logDebug("g_lvColors is object: " . (IsObject(g_lvColors) ? "YES" : "NO"))
    }

    if (!IsObject(g_lvColors)) {
        logToFile("ERROR: g_lvColors not initialized - cannot apply colors")
        return false
    }

    if (!items || items.Length = 0) {
        logToFile("No items to color")
        return false
    }

    ; Use configurable colors from main script
    if (DEBUG_ENABLED) {
        logDebug("Using configurable colors:")
        logDebug("  Normal: BG=0x" . Format("{:06X}", NORMAL_BG_COLOR) . ", Text=0x" . Format("{:06X}", NORMAL_TEXT_COLOR))
        logDebug("  Conflict: BG=0x" . Format("{:06X}", CONFLICT_BG_COLOR) . ", Text=0x" . Format("{:06X}", CONFLICT_TEXT_COLOR))
    }

    coloredRows := 0
    conflictRows := 0

    ; Apply colors to each row using global color configuration
    for intIndex, objRecord in items {
        ; Check for conflicts
        hasConflict := false
        if (IsObject(objRecord) && objRecord.HasOwnProp("conflict") && objRecord.conflict) {
            if (IsObject(objRecord.conflict) && objRecord.conflict.HasOwnProp("isConflict")) {
                hasConflict := objRecord.conflict.isConflict
            }
        }

        ; Apply appropriate color using global variables
        try {
            if (hasConflict) {
                success := g_lvColors.Row(intIndex, CONFLICT_BG_COLOR, CONFLICT_TEXT_COLOR)
                if (success) {
                    coloredRows++
                    conflictRows++
                    if (DEBUG_ENABLED && intIndex <= 3) {
                        logDebug("  ✓ Applied CONFLICT colors to row " . intIndex . " (" . objRecord.command . ")")
                    }
                }
            } else {
                success := g_lvColors.Row(intIndex, NORMAL_BG_COLOR, NORMAL_TEXT_COLOR)
                if (success) {
                    coloredRows++
                    if (DEBUG_ENABLED && intIndex <= 3) {
                        logDebug("  ✓ Applied NORMAL colors to row " . intIndex . " (" . objRecord.command . ")")
                    }
                }
            }
        } catch as err {
            logToFile("ERROR coloring row " . intIndex . ": " . err.Message)
        }
    }

    logToFile("✓ Row coloring completed: " . coloredRows . " rows colored (" . conflictRows . " conflicts)")

    ; Force redraw
    try {
        global g_mainListView
        hwndValue := GetControlProperty(g_mainListView, "Hwnd")
        if (hwndValue) {
            WinRedraw(hwndValue)
            logDebug("ListView redrawn")
        }
    } catch as err {
        logToFile("WARNING: Could not redraw ListView: " . err.Message)
    }

    return coloredRows > 0
}

; Function to populate ListView with hotkey and hotstring data
PopulateListView(listView, items) {
    logToFile("Populating ListView with " . items.Length . " items...")
    
    if (DEBUG_ENABLED) {
        logDebug("=== DETAILED LISTVIEW POPULATION ===")
        logDebug("ListView parameter type: " . Type(listView))
        logDebug("Items to process: " . items.Length)
    }

    if (!IsObject(listView)) {
        logToFile("ERROR: Invalid ListView passed to PopulateListView")
        return
    }

    ; Clear existing content
    try {
        listView.Delete()
        logDebug("ListView content cleared")
    } catch as err {
        logToFile("ERROR clearing ListView: " . err.Message)
        return
    }

    ; Add items to ListView
    itemsAdded := 0
    conflictItems := 0
    
    Loop items.Length {
        index := A_Index
        item := items[index]

        ; Determine conflict status
        hasConflict := false
        isExactConflict := false
        if (IsObject(item) && item.HasOwnProp("conflict") && item.conflict) {
            if (IsObject(item.conflict) && item.conflict.HasOwnProp("isConflict")) {
                hasConflict := item.conflict.isConflict
                if (hasConflict) {
                    conflictItems++
                    if (item.conflict.HasOwnProp("isExact")) {
                        isExactConflict := item.conflict.isExact
                    }
                }
            }
        }

        ; Format display text
        commandText := item.command != "" ? item.command : "[No Command]"
        if (hasConflict) {
            commandText := (isExactConflict ? "🚨 " : "⚠️ ") . commandText
        }

        typeText := item.type = "k" ? "Hotkey" : "Hotstring"
        if (hasConflict) {
            typeText .= (isExactConflict ? " (CONFLICT!)" : " (Similar)")
        }

        ; Build description
        actualDescription := item.description != "" ? item.description : (item.type = "k" ? "Hotkey action" : "Text replacement")
        
        conflictPrefix := ""
        if (hasConflict && IsSet(GetConflictStatusText) && Type(GetConflictStatusText) = "Func") {
            conflictDetails := GetConflictStatusText(item.conflict)
            conflictPrefix := (isExactConflict ? "🚨 EXACT CONFLICT " : "⚠️ POTENTIAL CONFLICT ") . conflictDetails . " → "
        }

        ; Add source indicator
        sourceIndicator := ""
        if (item.HasOwnProp("source")) {
            sourceType := item.source
            sourceIndicator := sourceType = "direct code" || sourceType = "direct" ? " [✓]" :
                              sourceType = "settings.ini" ? " [⚙]" :
                              InStr(sourceType, "Triggers") ? " [⚠]" : " [" . sourceType . "]"
        }

        finalDescription := conflictPrefix . actualDescription . sourceIndicator

        ; Get script path
        scriptPath := ""
        if (item.hwnd) {
            try {
                DetectHiddenWindows(true)
                scriptPath := WinGetTitle("ahk_id " . item.hwnd)
                scriptPath := RegExReplace(scriptPath, "\s+-\s+AutoHotkey.*$")
            } catch {
                ; Ignore path errors
            }
        }

        ; Add row to ListView
        try {
            rowIndex := listView.Add("", commandText, typeText, finalDescription, item.file, item.line, scriptPath)
            itemsAdded++
            
            if (DEBUG_ENABLED && index <= 3) {
                logDebug("Added row " . rowIndex . ": " . item.command . " (conflict=" . hasConflict . ")")
            }
        } catch as err {
            logToFile("ERROR adding row " . index . ": " . err.Message)
        }
    }

    logToFile("✓ ListView populated: " . itemsAdded . "/" . items.Length . " items (" . conflictItems . " conflicts)")
}

;================= End of GuiListView =================