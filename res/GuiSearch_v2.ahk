;================= GuiSearch v1.0.0 =================
; Search and filter functionality - handles search box changes, filter applications,
; and maintains ListView color consistency during search and filter operations.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

; Explicitly declare global functions and variables used from other modules
global logToFile
global logDebug
global g_searchEdit
global g_searchText
global g_typeDropDown
global g_fileDropDown
global g_mainListView
global g_mainGui
global arrayBaseList
global objScript
global g_lvColors
global ApplyRowColors
global DEBUG_ENABLED

; Handle search box changes
OnSearchChange() {
    global g_searchEdit, g_searchText

    ; Get current value
    currentValue := g_searchEdit.Value

    ; Update global and log
    g_searchText := currentValue
    logDebug("Search text changed: '" . currentValue . "'")

    ; Delay filter application to avoid too frequent updates
    SetTimer ApplyFilters, -300  ; 300ms delay
}

; Search button handler
SearchNow() {
    global g_searchEdit, g_searchText

    ; Get and log the current value
    currentValue := g_searchEdit.Value
    g_searchText := currentValue
    logToFile("Search initiated: '" . currentValue . "'")

    ; Apply filters immediately
    ApplyFilters()
}

; Apply all filters to the ListView with color reapplication
ApplyFilters() {
    global g_searchText, g_typeDropDown, g_fileDropDown, g_mainListView, arrayBaseList, g_mainGui, objScript, g_lvColors

    ; Get filter values
    searchText := g_searchText
    typeFilter := g_typeDropDown.Text
    fileFilter := g_fileDropDown.Text

    logToFile("Applying filters: search='" . searchText . "', type='" . typeFilter . "', file='" . fileFilter . "'")

    if (DEBUG_ENABLED) {
        logDebug("=== DETAILED FILTER APPLICATION ===")
        logDebug("Search text: '" . searchText . "'")
        logDebug("Type filter: '" . typeFilter . "'")
        logDebug("File filter: '" . fileFilter . "'")
        logDebug("Total items to filter: " . arrayBaseList.Length)
    }

    ; Check ListView before attempting operations
    if (!IsObject(g_mainListView)) {
        logToFile("ERROR: g_mainListView is not a valid object in ApplyFilters")
        return
    }

    ; Clear ListView
    try {
        g_mainListView.Delete()
        logDebug("Cleared ListView for filtering")
    } catch as err {
        logToFile("ERROR clearing ListView: " . err.Message)
        return
    }

    ; Clear existing colors if LV_Colors exists
    if (IsObject(g_lvColors)) {
        try {
            g_lvColors.Clear()
            logDebug("Cleared existing colors before filtering")
        } catch as err {
            logToFile("WARNING: Could not clear existing colors: " . err.Message)
        }
    }

    ; Create filtered array
    filteredItems := []
    hotkeyCount := 0
    hotstringCount := 0

    ; Build search pattern if needed
    searchPattern := searchText ? "i)\Q" . searchText . "\E" : ""

    if (DEBUG_ENABLED) {
        logDebug("Search pattern: '" . searchPattern . "'")
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
        logDebug("Filtering results:")
        logDebug("  Items matching search: " . filteredItems.Length)
        logDebug("  Hotkeys: " . hotkeyCount)
        logDebug("  Hotstrings: " . hotstringCount)
    }

    ; Update ListView with filtered items (no coloring yet)
    PopulateListView(g_mainListView, filteredItems)
    logToFile("✓ ListView updated with " . filteredItems.Length . " filtered items")

    ; CRITICAL: Reapply colors to the filtered items
    if (IsObject(g_lvColors) && filteredItems.Length > 0) {
        if (ApplyRowColors(filteredItems)) {
            logToFile("✓ Colors reapplied to " . filteredItems.Length . " filtered items")
            if (DEBUG_ENABLED) {
                logDebug("Row colors successfully reapplied after filtering")
            }
        } else {
            logToFile("WARNING: Failed to reapply colors to filtered items")
        }
    } else if (filteredItems.Length = 0) {
        logDebug("No items to color after filtering")
    } else {
        logToFile("WARNING: g_lvColors not available for color application")
    }

    ; Update status
    if (IsObject(g_mainGui)) {
        try {
            g_mainGui.Title := objScript.name . " - Found: " . filteredItems.Length . " items (" . hotkeyCount . " hotkeys, " . hotstringCount . " hotstrings)"
            logDebug("Updated GUI title with filter results")
        } catch as err {
            logToFile("ERROR updating GUI title: " . err.Message)
        }
    } else {
        logToFile("ERROR: g_mainGui is not a valid object when updating title")
    }

    logToFile("✓ Filter application completed")
}

;================= End of GuiSearch =================