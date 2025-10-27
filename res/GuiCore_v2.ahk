;================= GuiCore v1.0.0 =================
; Core GUI functionality - creates and manages the main application window,
; handles resizing, reload operations, and coordinates ListView color initialization.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

; Explicitly declare global functions and variables used from other modules
global logToFile
global logDebug
global logMsgBox
global objScript
global mapScriptList
global arrayBaseList
global g_mainGui
global g_searchEdit
global g_searchText
global g_typeDropDown
global g_fileDropDown
global g_mainListView
global g_contextMenu
global InitializeListViewColors
global ApplyRowColors
global DEBUG_ENABLED

; Create the main GUI for the application
createMainGui() {
    ; Explicitly reference global variables to ensure proper assignment
    global g_mainGui, g_searchEdit, g_typeDropDown, g_fileDropDown, g_mainListView

    logToFile("Starting GUI creation...")
    
    if (DEBUG_ENABLED) {
        logDebug("=== DETAILED GUI CREATION ===")
        logDebug("Creating main GUI window...")
    }

    ; Create main GUI window
    g_mainGui := Gui("+Resize", objScript.name)
    g_mainGui.OnEvent("Close", (*) => HandleExit())
    g_mainGui.OnEvent("Size", GuiResize)
    g_mainGui.SetFont("s12", "Segoe UI")

    logDebug("Main GUI window created, type: " . Type(g_mainGui))

    ; Add basic controls in horizontal layout - first row
    g_mainGui.Add("Text", "x10 y15", "Search Text:")
    g_searchEdit := g_mainGui.Add("Edit", "x100 y12 w150 h25")

    g_mainGui.Add("Text", "x260 y15", "Filter by Type:")
    g_typeDropDown := g_mainGui.Add("DropDownList", "x350 y12 w120 Choose1", ["All", "Hotkeys", "Hotstrings"])

    g_mainGui.Add("Text", "x480 y15", "Filter by File:")
    scriptArray := ["All"]
    for scriptName in mapScriptList
        scriptArray.Push(scriptName)
    g_fileDropDown := g_mainGui.Add("DropDownList", "x570 y12 w200 Choose1", scriptArray)

    ; Add buttons on the right side - first row
    searchButton := g_mainGui.Add("Button", "x780 y12 w110 h25", "Search")
    searchButton.OnEvent("Click", (*) => SearchNow())

    reloadButton := g_mainGui.Add("Button", "x895 y12 w110 h25", "Reload")
    reloadButton.OnEvent("Click", (*) => HandleReload())

    ; Add buttons on the right side - second row
    winShortcutsBtn := g_mainGui.Add("Button", "x780 y42 w110 h25", "Win Shortcuts")
    winShortcutsBtn.OnEvent("Click", (*) => ShowWindowsShortcuts())

    exitButton := g_mainGui.Add("Button", "x895 y42 w110 h25", "Exit")
    exitButton.OnEvent("Click", (*) => HandleExit())

    ; Add hotkey legend in red text
    g_mainGui.SetFont("s10 cRed", "Segoe UI")
    g_mainGui.Add("Text", "x10 y50", "Hotkey Legend: ^ = Ctrl  •  ! = Alt  •  + = Shift  •  # = Win")
    g_mainGui.SetFont("s12", "Segoe UI")

    ; Add source legend with symbols
    g_mainGui.SetFont("s9 cBlue", "Segoe UI")
    g_mainGui.Add("Text", "x420 y50 w350", "Source: [✓] = Direct Code  •  [⚙] = settings.ini  •  [⚠] = Triggers (no INI)")
    g_mainGui.SetFont("s12", "Segoe UI")

    ; Add color legend
    g_mainGui.SetFont("s9 cGreen", "Segoe UI")
    g_mainGui.Add("Text", "x10 y70 w400", "Colors: White = Normal Items  •  Red = Conflicts with Windows Shortcuts")
    g_mainGui.SetFont("s12", "Segoe UI")

    ; Create ListView control
    logDebug("Creating ListView control...")
    g_mainListView := g_mainGui.Add("ListView", "x10 y90 w1000 h470 Grid", ["Command", "Type", "Description", "Script Name", "Line", "Script Path"])

    ; Debug ListView creation
    logToFile("✓ ListView created successfully")
    if (DEBUG_ENABLED) {
        logDebug("ListView creation completed")
        logDebug("g_mainListView type: " . Type(g_mainListView))
        logDebug("g_mainListView is object: " . (IsObject(g_mainListView) ? "YES" : "NO"))
    }

    ; Configure ListView columns
    try {
        g_mainListView.ModifyCol(1, 150)  ; Command
        g_mainListView.ModifyCol(2, 80)   ; Type
        g_mainListView.ModifyCol(3, 300)  ; Description
        g_mainListView.ModifyCol(4, 150)  ; Script Name
        g_mainListView.ModifyCol(5, 50)   ; Line
        g_mainListView.ModifyCol(6, 200)  ; Path
        logDebug("ListView columns configured successfully")
    } catch as err {
        logToFile("ERROR configuring ListView columns: " err.Message)
    }

    ; Configure ListView events
    try {
        g_mainListView.OnEvent("ContextMenu", OnListViewContextMenu)
        logDebug("ListView events configured successfully")
    } catch as err {
        logToFile("ERROR configuring ListView events: " err.Message)
    }

    ; Initialize the context menu
    InitializeContextMenu()

    ; Populate the ListView with initial data
    logDebug("Populating ListView with initial data...")
    PopulateListView(g_mainListView, arrayBaseList)

    ; Show the GUI FIRST - critical for color initialization
    logToFile("Showing GUI window...")
    g_mainGui.Show("w1020 h625")
    logDebug("GUI window shown - ready for color initialization")

    ; Initialize colors AFTER the GUI is shown
    if (IsObject(g_mainListView)) {
        logDebug("Attempting to initialize ListView colors...")
        
        if (InitializeListViewColors(g_mainListView)) {
            logToFile("✓ ListView colors initialized")

            ; Apply colors to the rows
            if (ApplyRowColors(arrayBaseList)) {
                logToFile("✓ Row colors applied successfully")
            } else {
                logToFile("WARNING: Failed to apply row colors")
            }
        } else {
            logToFile("ERROR: Failed to initialize LV_Colors - rows will not be colored")
        }
    } else {
        logToFile("FATAL ERROR: g_mainListView is not an object - cannot initialize colors!")
    }

    ; Set up event handlers
    g_searchEdit.OnEvent("Change", (*) => OnSearchChange())
    g_typeDropDown.OnEvent("Change", (*) => ApplyFilters())
    g_fileDropDown.OnEvent("Change", (*) => ApplyFilters())

    ; Set focus to search edit box
    g_searchEdit.Focus()

    logToFile("✓ GUI created successfully with ListView coloring")
    return g_mainGui
}

; Handle GUI resizing
GuiResize(thisGui, minMax, width, height) {
    global g_mainListView

    if (minMax = -1) ; Minimized
        return

    ; Resize ListView to fill available space
    listViewW := width - 20
    listViewH := height - 100

    if (IsObject(g_mainListView)) {
        try {
            g_mainListView.Move(,, listViewW, listViewH)
            logDebug("ListView resized successfully")
        } catch as err {
            logToFile("ERROR moving ListView: " . err.Message)
        }
    } else {
        logToFile("ERROR: g_mainListView is not a valid object in GuiResize")
    }
}

; Handle Reload menu option
HandleReload() {
    global objScript, arrayBaseList, mapScriptList, g_mainListView, g_lvColors

    logToFile("Reload requested...")

    try {
        ; Clear existing data
        arrayBaseList := []
        mapScriptList := Map()

        ; Clear the ListView
        if (IsObject(g_mainListView)) {
            g_mainListView.Delete()
        }

        ; Clear existing colors
        if (IsObject(g_lvColors)) {
            try {
                g_lvColors.Clear()
                logDebug("Cleared existing ListView colors")
            } catch as err {
                logToFile("WARNING: Could not clear existing colors: " . err.Message)
            }
        }

        ; Get list of scripts again
        arrayScripts := getRunningScripts()

        if (arrayScripts.Length = 0) {
            logToFile("No scripts found during reload")
            return
        }

        ; Load commands again
        loadCommands(arrayScripts)

        ; Update file dropdown
        scriptArray := ["All"]
        for scriptName in mapScriptList
            scriptArray.Push(scriptName)

        global g_fileDropDown
        g_fileDropDown.Delete()
        g_fileDropDown.Add(scriptArray)
        g_fileDropDown.Choose(1)

        ; Repopulate ListView
        PopulateListView(g_mainListView, arrayBaseList)

        ; Re-apply colors
        if (IsObject(g_lvColors)) {
            if (ApplyRowColors(arrayBaseList)) {
                logDebug("Row colors re-applied successfully after reload")
            } else {
                logToFile("WARNING: Failed to re-apply row colors after reload")
            }
        }

        ; Reset filters
        global g_typeDropDown, g_searchEdit
        g_typeDropDown.Choose(1)
        g_searchEdit.Value := ""

        ; Update window title
        global gHotkeyCount, gHotstringCount
        g_mainGui.Title := objScript.name " - Found: " arrayBaseList.Length " items (" gHotkeyCount " hotkeys, " gHotstringCount " hotstrings)"

        logToFile("✓ Reload completed successfully")

    } catch as err {
        logToFile("ERROR during reload: " . err.Message)
    }
}

; Handle Exit menu option and window close
HandleExit() {
    logToFile("Application exit requested...")

    try {
        ; Clean up LV_Colors if it exists
        global g_lvColors
        if (IsObject(g_lvColors)) {
            try {
                g_lvColors.ShowColors(false)
                logDebug("Disabled LV_Colors before exit")
            } catch as err {
                logToFile("WARNING: Could not disable LV_Colors: " . err.Message)
            }
        }

        logDebug("Cleanup completed")

    } catch as err {
        logToFile("ERROR during exit cleanup: " . err.Message)
    }

    logToFile("Application exit completed")
    ExitApp(0)
}

;================= End of GuiCore =================