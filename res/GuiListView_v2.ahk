;================= GuiListView v1.0.0 =================
; ListView functionality - manages the main ListView control with configurable
; row coloring, populates data, and handles color application based on conflict status.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

#Include CoreModule_v2.ahk
moduleCore := CoreModule()

#Include Class_LV_Colors_v2.ahk

#Include D:\OneDrive\AHK\Includes\Peep_v2.ahk
#Include D:\OneDrive\AHK\Includes\jsongo_v2.ahk

; Declare global variables used from other modules
global g_mainListView
global g_lvColors
; NMS Next 4 lines commented
; global moduleCore.logToFile
; global moduleCore.logDebug
; global GetConflictStatusText
; global DEBUG_ENABLED

; NMS Next 6 lines added
DEBUG_ENABLED := IniRead('Lookup.ini', 'Debug', 'DEBUG_ENABLED')
; Declare global color configuration variables (set in main script)
NORMAL_BG_COLOR := IniRead('Lookup.ini', 'ListView', 'NORMAL_BG_COLOR')
NORMAL_TEXT_COLOR := IniRead('Lookup.ini', 'ListView', 'NORMAL_TEXT_COLOR')
CONFLICT_BG_COLOR := IniRead('Lookup.ini', 'ListView', 'CONFLICT_BG_COLOR')
CONFLICT_TEXT_COLOR := IniRead('Lookup.ini', 'ListView', 'CONFLICT_TEXT_COLOR')

; Initialize g_lvColors to prevent unassigned variable errors
if (!IsSet(g_lvColors)) {
    g_lvColors := ''
}

Class GuiListView {
    ; New : 25-01-24
    ; GetControlProperty : (control, propertyName) : Safely get control properties with multiple methods
    ; control : object - Control object to query
    ; propertyName : string - Property name to retrieve
    ; Returns : string|int - Property value or empty string if not found
    GetControlProperty(control, propertyName) {
        ; NMS 1 line added
        moduleCore.logToFile('============= GuiListView / GetControlProperty ===============', 'NMS')
        if (!IsObject(control)) {
            return ''
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
        if (propertyName = 'Hwnd') {
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
        if (propertyName = 'Type') {
            try {
                return control.ClassNN
            } catch {
                ; Continue
            }
        }
        
        return ''  ; Property not found
    }

    ; New : 25-01-24
    ; InitializeListViewColors : (listView) : Create and initialize LV_Colors for the ListView
    ; listView : object - ListView control object
    ; Returns : bool - True on success, False on failure
    InitializeListViewColors(listView) {
        ; NMS 1 line added
        moduleCore.logToFile('============= GuiListView / InitializeListViewColors ===============', 'NMS')
        global g_lvColors

        ; Always log the basic initialization
        moduleCore.logToFile('Initializing ListView colors...')
        
        ; Enhanced debug logging only if debug enabled
        if (DEBUG_ENABLED) {
            moduleCore.logDebug('=== DETAILED LISTVIEW COLOR INITIALIZATION ===')
            moduleCore.logDebug('AutoHotkey version: ' . A_AhkVersion)
            moduleCore.logDebug('Parameter received - Type: ' . Type(listView))
            moduleCore.logDebug('Parameter received - Is Object: ' . (IsObject(listView) ? 'YES' : 'NO'))
            
            ; Log color configuration
            moduleCore.logDebug('Color configuration:')
            moduleCore.logDebug('  NORMAL_BG_COLOR: 0x' . Format('{:06X}', NORMAL_BG_COLOR))
            moduleCore.logDebug('  NORMAL_TEXT_COLOR: 0x' . Format('{:06X}', NORMAL_TEXT_COLOR))
            moduleCore.logDebug('  CONFLICT_BG_COLOR: 0x' . Format('{:06X}', CONFLICT_BG_COLOR))
            moduleCore.logDebug('  CONFLICT_TEXT_COLOR: 0x' . Format('{:06X}', CONFLICT_TEXT_COLOR))
            
            if (IsObject(listView)) {
                moduleCore.logDebug('Testing property access methods...')
                
                ; Test Hwnd property with all methods
                hwndValue := this.GetControlProperty(listView, 'Hwnd')
                moduleCore.logDebug('Hwnd via GetControlProperty: ' . (hwndValue ? hwndValue : 'NOT FOUND'))
                
                ; Test Type property
                typeValue := this.GetControlProperty(listView, 'Type')
                moduleCore.logDebug('Type via GetControlProperty: ' . (typeValue ? typeValue : 'NOT FOUND'))
            }
        }

        ; Validate ListView control
        if (!IsObject(listView)) {
            moduleCore.logToFile('ERROR: Invalid ListView control - not an object')
            return false
        }
        
        ; Get Hwnd using our safe method
        hwndValue := this.GetControlProperty(listView, 'Hwnd')
        if (!hwndValue) {
            moduleCore.logToFile('ERROR: Cannot get Hwnd property from ListView control')
            if (DEBUG_ENABLED) {
                moduleCore.logDebug('This suggests a version compatibility issue with AutoHotkey ' . A_AhkVersion)
            }
            return false
        }
        
        ; Validate that it's actually a ListView
        typeValue := this.GetControlProperty(listView, 'Type')
        if (typeValue && typeValue != 'ListView') {
            moduleCore.logToFile('ERROR: Control is not a ListView, it`'s a ' . typeValue)
            return false
        }

        try {
            moduleCore.logDebug('Attempting to create LV_Colors instance with Hwnd: ' . hwndValue)

            ; Create LV_Colors with the ListView control object
            g_lvColors := LV_Colors(listView)

            if (DEBUG_ENABLED) {
                moduleCore.logDebug('LV_Colors constructor completed')
                moduleCore.logDebug('g_lvColors type: ' . Type(g_lvColors))
                moduleCore.logDebug('g_lvColors is object: ' . (IsObject(g_lvColors) ? 'YES' : 'NO'))
            }

            if (!IsObject(g_lvColors)) {
                moduleCore.logToFile('ERROR: Failed to create LV_Colors instance')
                return false
            }

            ; Enable colors
            moduleCore.logDebug('Enabling colors with ShowColors(true)...')
            g_lvColors.ShowColors(true)

            moduleCore.logToFile('✓ ListView colors initialized successfully')
            return true

        } catch as err {
            moduleCore.logToFile('CRITICAL ERROR: Exception in LV_Colors creation: ' . err.Message)
            
            if (DEBUG_ENABLED) {
                moduleCore.logDebug('Detailed error information:')
                moduleCore.logDebug('  Error message: ' . err.Message)
                moduleCore.logDebug('  Error extra: ' . err.Extra)
                moduleCore.logDebug('  Error line: ' . err.Line)
                moduleCore.logDebug('  Error file: ' . err.File)
                moduleCore.logDebug('  AutoHotkey version: ' . A_AhkVersion)
            }
            
            g_lvColors := ''
            return false
        }
    }

    ; New : 25-01-24
    ; ApplyRowColors : (items) : Apply colors to ListView rows based on conflict status
    ; items : array - Array of items to color
    ; Returns : bool - True if any rows colored, False otherwise
    ApplyRowColors(items) {
        ; NMS 1 line added
        moduleCore.logToFile('============= GuiListView / ApplyRowColors ===============', 'NMS')
        global g_lvColors

        moduleCore.logToFile('Applying row colors to ' . items.Length . ' items...')
        
        if (DEBUG_ENABLED) {
            moduleCore.logDebug('=== DETAILED ROW COLOR APPLICATION ===')
            moduleCore.logDebug('g_lvColors type: ' . Type(g_lvColors))
            moduleCore.logDebug('g_lvColors is object: ' . (IsObject(g_lvColors) ? 'YES' : 'NO'))
        }

        if (!IsObject(g_lvColors)) {
            moduleCore.logToFile('ERROR: g_lvColors not initialized - cannot apply colors')
            return false
        }

        if (!items || items.Length = 0) {
            moduleCore.logToFile('No items to color')
            return false
        }

        ; Use configurable colors from main script
        if (DEBUG_ENABLED) {
            moduleCore.logDebug('Using configurable colors:')
            moduleCore.logDebug('  Normal: BG=0x' . Format('{:06X}', NORMAL_BG_COLOR) . ', Text=0x' . Format('{:06X}', NORMAL_TEXT_COLOR))
            moduleCore.logDebug('  Conflict: BG=0x' . Format('{:06X}', CONFLICT_BG_COLOR) . ', Text=0x' . Format('{:06X}', CONFLICT_TEXT_COLOR))
        }

        coloredRows := 0
        conflictRows := 0

        ; Apply colors to each row using global color configuration
        for intIndex, objRecord in items {
            ; Check for conflicts
            hasConflict := false
            if (IsObject(objRecord) && objRecord.HasOwnProp('conflict') && objRecord.conflict) {
                if (IsObject(objRecord.conflict) && objRecord.conflict.HasOwnProp('isConflict')) {
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
                            moduleCore.logDebug('  ✓ Applied CONFLICT colors to row ' . intIndex . ' (' . objRecord.command . ')')
                        }
                    }
                } else {
                    success := g_lvColors.Row(intIndex, NORMAL_BG_COLOR, NORMAL_TEXT_COLOR)
                    if (success) {
                        coloredRows++
                        if (DEBUG_ENABLED && intIndex <= 3) {
                            moduleCore.logDebug('  ✓ Applied NORMAL colors to row ' . intIndex . ' (' . objRecord.command . ')')
                        }
                    }
                }
            } catch as err {
                moduleCore.logToFile('ERROR coloring row ' . intIndex . ': ' . err.Message)
            }
        }

        moduleCore.logToFile('✓ Row coloring completed: ' . coloredRows . ' rows colored (' . conflictRows . ' conflicts)')

        ; Force redraw
        try {
            global g_mainListView
            hwndValue := this.GetControlProperty(g_mainListView, 'Hwnd')
            if (hwndValue) {
                WinRedraw(hwndValue)
                moduleCore.logDebug('ListView redrawn')
            }
        } catch as err {
            moduleCore.logToFile('WARNING: Could not redraw ListView: ' . err.Message)
        }

        return coloredRows > 0
    }

    ; New : 25-01-24
    ; PopulateListView : (listView, items) : Populate ListView with hotkey and hotstring data
    ; listView : object - ListView control object
    ; items : array - Array of items to display
    PopulateListView(listView, items) {
        ; NMS 1 line added
        moduleCore.logToFile('============= GuiListView / PopulateListView ===============', 'NMS')
        moduleCore.logToFile('Populating ListView with ' . items.Length . ' items...')
        if (DEBUG_ENABLED) {
            moduleCore.logDebug('=== DETAILED LISTVIEW POPULATION ===')
            moduleCore.logDebug('ListView parameter type: ' . Type(listView))
            moduleCore.logDebug('Items to process: ' . items.Length)
        }

        if (!IsObject(listView)) {
            moduleCore.logToFile('ERROR: Invalid ListView passed to PopulateListView')
            return
        }

        ; Clear existing content
        try {
            listView.Delete()
            moduleCore.logDebug('ListView content cleared')
        } catch as err {
            moduleCore.logToFile('ERROR clearing ListView: ' . err.Message)
            return
        }

        ; Add items to ListView
        itemsAdded := 0
        conflictItems := 0
        
        listView.opt('-Redraw') ;; hud
        Loop items.Length {
            index := A_Index
            item := items[index]

            ; Determine conflict status
            hasConflict := false
            isExactConflict := false
            if (IsObject(item) && item.HasOwnProp('conflict') && item.conflict) {
                if (IsObject(item.conflict) && item.conflict.HasOwnProp('isConflict')) {
                    hasConflict := item.conflict.isConflict
                    if (hasConflict) {
                        conflictItems++
                        if (item.conflict.HasOwnProp('isExact')) {
                            isExactConflict := item.conflict.isExact
                        }
                    }
                }
            }

            ; Format display text
            commandText := item.command != '' ? item.command : '[No Command]'
            if (hasConflict) {
                commandText := (isExactConflict ? '🚨 ' : '⚠️ ') . commandText
            }

            typeText := item.type = 'k' ? 'Hotkey' : 'Hotstring'
            if (hasConflict) {
                typeText .= (isExactConflict ? ' (CONFLICT!)' : ' (Similar)')
            }

            ; Build description
            actualDescription := item.description != '' ? item.description : (item.type = 'k' ? 'Hotkey action' : 'Text replacement')
            
            conflictPrefix := ''
            if (hasConflict && IsSet(GetConflictStatusText) && Type(GetConflictStatusText) = 'Func') {
                conflictDetails := GetConflictStatusText(item.conflict)
                conflictPrefix := (isExactConflict ? '🚨 EXACT CONFLICT ' : '⚠️ POTENTIAL CONFLICT ') . conflictDetails . ' → '
            }

            ; Add source indicator
            sourceIndicator := ''
            if (item.HasOwnProp('source')) {
                sourceType := item.source
                sourceIndicator := sourceType = 'direct code' || sourceType = 'direct' ? ' [✓]' :
                                sourceType = 'settings.ini' ? ' [⚙]' :
                                InStr(sourceType, 'Triggers') ? ' [⚡]' : ' [' . sourceType . ']'
            }

            finalDescription := conflictPrefix . actualDescription . sourceIndicator

            ; NMS 1 line added for displaying scriptPath at final window
            scriptPath := StrReplace(item.path, 'D:\OneDrive\AutoHotkey\AHK_')

            ; NMS 10 lines commented because foregoing line already takes care of scriptPath
            ; if (item.hwnd) {
            ;     try {
            ;         DetectHiddenWindows(true)
            ;         scriptPath := WinGetTitle('ahk_id ' . item.hwnd)
            ;         scriptPath := RegExReplace(scriptPath, '\s+-\s+AutoHotkey.*$')
            ;     } catch {
            ;         ; Ignore path errors
            ;     }
            ; } else {
            ; }

            ; Add row to ListView
            try {
                rowIndex := listView.Add('', commandText, typeText, finalDescription, item.file, item.line, scriptPath)
                itemsAdded++
                
                if (DEBUG_ENABLED && index <= 3) {
                    moduleCore.logDebug('Added row ' . rowIndex . ': ' . item.command . ' (conflict=' . hasConflict . ')')
                }
            } catch as err {
                moduleCore.logToFile('ERROR adding row ' . index . ': ' . err.Message)
            }
        }
        listView.opt('+Redraw') ;; hud

        moduleCore.logToFile('✓ ListView populated: ' . itemsAdded . '/' . items.Length . ' items (' . conflictItems . ' conflicts)')
    }
}
;================= End of GuiListView =================
