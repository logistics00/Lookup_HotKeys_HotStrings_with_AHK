;================= GuiCore v1.0.0 =================
; Core GUI functionality - creates and manages the main application window,
; handles resizing, reload operations, and coordinates ListView color initialization.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

#Include CoreModule_v2.ahk
moduleCore := CoreModule()

#Include GuiSearch_v2.ahk
searchGui := GuiSearch()

#Include GuiContextMenu_v2.ahk
contextMenuGui := GuiContextMenu()

#Include GuiListView_v2.ahk
listViewGui := GuiListView()

#Include ScriptScanner_v2.ahk
scannerScript := ScriptScanner()

#Include WindowsShortcuts_v2.ahk
shortcutsWindows := WindowsShortcuts()

; #Include GuiListView.ahk2

; Explicitly declare global functions and variables used from other modules

; NMS Next 3 lines commented because of Class concepr
; global logToFile
; global logDebug
; global logMsgBox

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

;NMS Next 2 lines commented because of Class concept
; global InitializeListViewColors
; global ApplyRowColors

; NMS Next line commented and following line added because of Lookup.ini
; global DEBUG_ENABLED
DEBUG_ENABLED := IniRead('Lookup.ini', 'Debug', 'DEBUG_ENABLED')

Class GuiCore {
    ; Create the main GUI for the application
    createMainGui() {
        ; Explicitly reference global variables to ensure proper assignment
        global g_mainGui, g_searchEdit, g_typeDropDown, g_fileDropDown, g_mainListView

        moduleCore.logToFile("Starting GUI creation...")
        
        if (DEBUG_ENABLED) {
            moduleCore.logDebug("=== DETAILED GUI CREATION ===")
            moduleCore.logDebug("Creating main GUI window...")
        }

    ; Create main GUI window
        g_mainGui := Gui("+Resize", objScript.name)
        g_mainGui.OnEvent("Close", (*) => this.HandleExit())
        ; g_mainGui.OnEvent("Size", (*) => GuiResize)
        g_mainGui.OnEvent("Size",  (*) => this.GuiResize)
        g_mainGui.SetFont("s12", "Segoe UI" )

        moduleCore.logDebug("Main GUI window created, type: " . Type(g_mainGui))

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
        searchButton.OnEvent("Click", (*) => searchGui.SearchNow())

        reloadButton := g_mainGui.Add("Button", "x895 y12 w110 h25", "Reload")
        reloadButton.OnEvent("Click", (*) => this.HandleReload())

        ; Add buttons on the right side - second row
        winShortcutsBtn := g_mainGui.Add("Button", "x780 y42 w110 h25", "Win Shortcuts")
        winShortcutsBtn.OnEvent("Click", (*) => shortcutsWindows.ShowWindowsShortcuts())

        exitButton := g_mainGui.Add("Button", "x895 y42 w110 h25", "Exit")
        exitButton.OnEvent("Click", (*) => this.HandleExit())

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
        moduleCore.logDebug("Creating ListView control...")
        g_mainListView := g_mainGui.Add("ListView", "x10 y90 w1000 h520 Grid", ["Command", "Type", "Description", "Script Name", "Line", "Script Path"])

        ; Debug ListView creation
        moduleCore.logToFile("✓ ListView created successfully")
        if (DEBUG_ENABLED) {
            moduleCore.logDebug("ListView creation completed")
            moduleCore.logDebug("g_mainListView type: " . Type(g_mainListView))
            moduleCore.logDebug("g_mainListView is object: " . (IsObject(g_mainListView) ? "YES" : "NO"))
        }

        ; Configure ListView columns
        try {
            g_mainListView.ModifyCol(1, 150)  ; Command
            g_mainListView.ModifyCol(2, 80)   ; Type
            g_mainListView.ModifyCol(3, 300)  ; Description
            g_mainListView.ModifyCol(4, 150)  ; Script Name
            g_mainListView.ModifyCol(5, 50)   ; Line
            g_mainListView.ModifyCol(6, 200)  ; Path
            moduleCore.logDebug("ListView columns configured successfully")
        } catch as err {
            moduleCore.logToFile("ERROR configuring ListView columns: " err.Message)
        }

        ; Configure ListView events
        try {
            g_mainListView.OnEvent("ContextMenu", this.OnListViewContextMenu)
            moduleCore.logDebug("ListView events configured successfully")
        } catch as err {
            moduleCore.logToFile("ERROR configuring ListView events: " err.Message)
        }

        ; Initialize the context menu
        contextMenuGui.InitializeContextMenu()

        ; Populate the ListView with initial data
        moduleCore.logDebug("Populating ListView with initial data...")
        listViewGui.PopulateListView(g_mainListView, arrayBaseList)

        ; Show the GUI FIRST - critical for color initialization
        moduleCore.logToFile("Showing GUI window...")
        g_mainGui.Show("w1020 h625")
        moduleCore.logDebug("GUI window shown - ready for color initialization")

        ; Initialize colors AFTER the GUI is shown
        if (IsObject(g_mainListView)) {
            moduleCore.logDebug("Attempting to initialize ListView colors...")
            
            if (listViewGui.InitializeListViewColors(g_mainListView)) {
                moduleCore.logToFile("✓ ListView colors initialized")

                ; Apply colors to the rows
                if (listViewGui.ApplyRowColors(arrayBaseList)) {
                    moduleCore.logToFile("✓ Row colors applied successfully")
                } else {
                    moduleCore.logToFile("WARNING: Failed to apply row colors")
                }
            } else {
                moduleCore.logToFile("ERROR: Failed to initialize LV_Colors - rows will not be colored")
            }
        } else {
            moduleCore.logToFile("FATAL ERROR: g_mainListView is not an object - cannot initialize colors!")
        }

        ; Set up event handlers
        g_searchEdit.OnEvent("Change", (*) => searchGui.OnSearchChange())
        g_typeDropDown.OnEvent("Change", (*) => searchGui.ApplyFilters())
        g_fileDropDown.OnEvent("Change", (*) => searchGui.ApplyFilters())

        ; Set focus to search edit box
        g_searchEdit.Focus()

        moduleCore.logToFile("✓ GUI created successfully with ListView coloring")
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
                moduleCore.logDebug("ListView resized successfully")
            } catch as err {
                moduleCore.logToFile("ERROR moving ListView: " . err.Message)
            }
        } else {
            moduleCore.logToFile("ERROR: g_mainListView is not a valid object in GuiResize")
        }
    }

    ; Handle Reload menu option
    HandleReload() {
        global objScript, arrayBaseList, mapScriptList, g_mainListView, g_lvColors

        moduleCore.logToFile("Reload requested...")

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
                    moduleCore.logDebug("Cleared existing ListView colors")
                } catch as err {
                    moduleCore.logToFile("WARNING: Could not clear existing colors: " . err.Message)
                }
            }

            ; Get list of scripts again
            arrayScripts := this.getRunningScripts()

            if (arrayScripts.Length = 0) {
                moduleCore.logToFile("No scripts found during reload")
                return
            }

            ; Load commands again
            scannerScript.loadCommands(arrayScripts)

            ; Update file dropdown
            scriptArray := ["All"]
            for scriptName in mapScriptList
                scriptArray.Push(scriptName)

            global g_fileDropDown
            g_fileDropDown.Delete()
            g_fileDropDown.Add(scriptArray)
            g_fileDropDown.Choose(1)

            ; Repopulate ListView
            listViewGui.PopulateListView(g_mainListView, arrayBaseList)

            ; Re-apply colors
            if (IsObject(g_lvColors)) {
                if (listViewGui.ApplyRowColors(arrayBaseList)) {
                    moduleCore.logDebug("Row colors re-applied successfully after reload")
                } else {
                    moduleCore.logToFile("WARNING: Failed to re-apply row colors after reload")
                }
            }

            ; Reset filters
            global g_typeDropDown, g_searchEdit
            g_typeDropDown.Choose(1)
            g_searchEdit.Value := ""

            ; Update window title
            global gHotkeyCount, gHotstringCount
            g_mainGui.Title := objScript.name " - Found: " arrayBaseList.Length " items (" gHotkeyCount " hotkeys, " gHotstringCount " hotstrings)"

            moduleCore.logToFile("✓ Reload completed successfully")

        } catch as err {
            moduleCore.logToFile("ERROR during reload: " . err.Message)
        }
    }

    ; Handle Exit menu option and window close
    HandleExit() {
        moduleCore.logToFile("Application exit requested...")

        try {
            ; Clean up LV_Colors if it exists
            global g_lvColors
            if (IsObject(g_lvColors)) {
                try {
                    g_lvColors.ShowColors(false)
                    moduleCore.logDebug("Disabled LV_Colors before exit")
                } catch as err {
                    moduleCore.logToFile("WARNING: Could not disable LV_Colors: " . err.Message)
                }
            }

            moduleCore.logDebug("Cleanup completed")

        } catch as err {
            moduleCore.logToFile("ERROR during exit cleanup: " . err.Message)
        }

        moduleCore.logToFile("Application exit completed")
        if myFile != 0
            myFile.Close() ;; hud
        ExitApp(0)
    }
}
;================= End of GuiCore =================