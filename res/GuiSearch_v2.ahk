;================= GuiSearch v1.0.0 =================
; Search and filter functionality - handles search box changes, filter applications,
; and maintains ListView color consistency during search and filter operations.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

#Include CoreModule_v2.ahk
moduleCore := CoreModule()

#Include GuiListView_v2.ahk
listViewGui := GuiListView()

; Explicitly declare global functions and variables used from other modules
; NMS Next two lines commented
; global moduleCore.logToFile
; global moduleCore.logDebug
global g_searchEdit
global g_searchText
global g_typeDropDown
global g_fileDropDown
global g_mainListView
global g_mainGui
global arrayBaseList
global objScript
global g_lvColors
; NMS Next line commented
; global ApplyRowColors
; global DEBUG_ENABLED
DEBUG_ENABLED := IniRead('Lookup.ini', 'Debug', 'DEBUG_ENABLED')

Class GuiSearch {
    ; Handle search box changes
    OnSearchChange() {
        ; NMS 1 line added
        moduleCore.logToFile("============= GuiSearch / OnSearchChange ===============", 'NMS')
        global g_searchEdit, g_searchText

        ; Get current value
        currentValue := g_searchEdit.Value

        ; Update global and log
        g_searchText := currentValue
        moduleCore.logDebug("Search text changed: '" . currentValue . "'")

        ; Delay filter application to avoid too frequent updates
        ; NMS Changed next 3 lines
        ; SetTimer this.ApplyFilters, -300  ; 300ms delay
        Sleep(300)
        this.ApplyFilters()
    }

    ; Search button handler
    SearchNow() {
        ; NMS 1 line added
        moduleCore.logToFile("============= GuiSearch / SearchNow ===============", 'NMS')
        global g_searchEdit, g_searchText

        ; Get and log the current value
        currentValue := g_searchEdit.Value
        g_searchText := currentValue
        moduleCore.logToFile("Search initiated: '" . currentValue . "'")

        ; Apply filters immediately
        this.ApplyFilters()
    }

    ; Apply all filters to the ListView with color reapplication
    ApplyFilters() {
        ; NMS 1 line added
        moduleCore.logToFile("============= GuiSearch / ApplyFilters ===============", 'NMS')
        global g_searchText, g_typeDropDown, g_fileDropDown, g_mainListView, arrayBaseList, g_mainGui, objScript, g_lvColors

        ; Get filter values
        searchText := g_searchText
        typeFilter := g_typeDropDown.Text
        fileFilter := g_fileDropDown.Text

        moduleCore.logToFile("Applying filters: search='" . searchText . "', type='" . typeFilter . "', file='" . fileFilter . "'")

        if (DEBUG_ENABLED) {
            moduleCore.logDebug("=== DETAILED FILTER APPLICATION ===")
            moduleCore.logDebug("Search text: '" . searchText . "'")
            moduleCore.logDebug("Type filter: '" . typeFilter . "'")
            moduleCore.logDebug("File filter: '" . fileFilter . "'")
            moduleCore.logDebug("Total items to filter: " . arrayBaseList.Length)
        }

        ; Check ListView before attempting operations
        if (!IsObject(g_mainListView)) {
            moduleCore.logToFile("ERROR: g_mainListView is not a valid object in ApplyFilters")
            return
        }

        ; Clear ListView
        try {
            g_mainListView.Delete()
            moduleCore.logDebug("Cleared ListView for filtering")
        } catch as err {
            moduleCore.logToFile("ERROR clearing ListView: " . err.Message)
            return
        }

        ; Clear existing colors if LV_Colors exists
        if (IsObject(g_lvColors)) {
            try {
                g_lvColors.Clear()
                moduleCore.logDebug("Cleared existing colors before filtering")
            } catch as err {
                moduleCore.logToFile("WARNING: Could not clear existing colors: " . err.Message)
            }
        }

        ; Create filtered array
        filteredItems := []
        hotkeyCount := 0
        hotstringCount := 0

        ; Build search pattern if needed
        searchPattern := searchText ? "i)\Q" . searchText . "\E" : ""

        if (DEBUG_ENABLED) {
            moduleCore.logDebug("Search pattern: '" . searchPattern . "'")
        }

        ; Filter items
        for item in arrayBaseList {
            ; Check if meets all filter criteria
            matchesSearch := !searchPattern ||
                            item.command ~= searchPattern ||
                            item.description ~= searchPattern ||
                            item.file ~= searchPattern

            matchesType := typeFilter = "All" ||
                        (typeFilter = "Hotkeys" && item.type = "k") ||
                        (typeFilter = "Hotstrings" && item.type = "s")

            matchesFile := fileFilter = "All" || item.file = fileFilter

            ; Add to filtered list if matches all criteria
            if (matchesSearch && matchesType && matchesFile) {
                filteredItems.Push(item)

                ; Track counts
                if (item.type = "k")
                    hotkeyCount++
                else
                    hotstringCount++
            }
        }

        if (DEBUG_ENABLED) {
            moduleCore.logDebug("Filtering results:")
            moduleCore.logDebug("  Items matching search: " . filteredItems.Length)
            moduleCore.logDebug("  Hotkeys: " . hotkeyCount)
            moduleCore.logDebug("  Hotstrings: " . hotstringCount)
        }

        ; Update ListView with filtered items (no coloring yet)
        listViewGui.PopulateListView(g_mainListView, filteredItems)
        moduleCore.logToFile("✓ ListView updated with " . filteredItems.Length . " filtered items")

        ; CRITICAL: Reapply colors to the filtered items
        if (IsObject(g_lvColors) && filteredItems.Length > 0) {
            if (listViewGui.ApplyRowColors(filteredItems)) {
                moduleCore.logToFile("✓ Colors reapplied to " . filteredItems.Length . " filtered items")
                if (DEBUG_ENABLED) {
                    moduleCore.logDebug("Row colors successfully reapplied after filtering")
                }
            } else {
                moduleCore.logToFile("WARNING: Failed to reapply colors to filtered items")
            }
        } else if (filteredItems.Length = 0) {
            moduleCore.logDebug("No items to color after filtering")
        } else {
            moduleCore.logToFile("WARNING: g_lvColors not available for color application")
        }

        ; Update status
        if (IsObject(g_mainGui)) {
            try {
                g_mainGui.Title := objScript.name . " - Found: " . filteredItems.Length . " items (" . hotkeyCount . " hotkeys, " . hotstringCount . " hotstrings)"
                moduleCore.logDebug("Updated GUI title with filter results")
            } catch as err {
                moduleCore.logToFile("ERROR updating GUI title: " . err.Message)
            }
        } else {
            moduleCore.logToFile("ERROR: g_mainGui is not a valid object when updating title")
        }

        moduleCore.logToFile("✓ Filter application completed")
    }
}
;================= End of GuiSearch =================