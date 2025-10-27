;================= GuiContextMenu v1.0.0 =================
; Context menu functionality for AHKHotkeyStringLookup - provides right-click
; context menu options for ListView items including script editing functionality.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

; Explicitly declare global functions and variables used from other modules
global logToFile
global logMsgBox
global objScript
global g_mainListView
global g_contextMenu

; Initialize the context menu with options
InitializeContextMenu() {
    global g_contextMenu

    ; Create context menu for ListView
    g_contextMenu := Menu()
    g_contextMenu.Add("Edit Script", OnMenuEditScript)

    logToFile("Context menu initialized with Edit Script option")
}

; Handle ListView context menu
OnListViewContextMenu(ctrl, itemPos, *) {
    global g_mainListView, g_contextMenu

    ; Check that we have valid objects
    if (!IsObject(g_mainListView)) {
        logToFile("ERROR: Invalid g_mainListView in OnListViewContextMenu")
        return
    }

    if (!IsObject(g_contextMenu)) {
        logToFile("ERROR: Invalid g_contextMenu in OnListViewContextMenu")
        return
    }

    ; Check if an item is selected
    try {
        row := g_mainListView.GetNext()

        if (!row) {
            ; If no item is selected, try to select the item under the mouse
            if (itemPos) {
                row := g_mainListView.GetNext(0, "Pos " itemPos)
                if (row)
                    g_mainListView.Modify(row, "Select Focus")
            }
        }

        ; If we have a selected row, show the context menu
        if (row) {
            command := g_mainListView.GetText(row, 1)
            logToFile("Showing context menu for row " row " with command: " command)
            g_contextMenu.Show()
        }
    } catch as err {
        logToFile("ERROR in context menu handling: " err.Message)
    }
}

; Menu handlers
OnMenuEditScript(*) {
    global g_mainListView

    if (!IsObject(g_mainListView)) {
        logToFile("ERROR: Invalid g_mainListView in OnMenuEditScript")
        return
    }

    try {
        row := g_mainListView.GetNext()
        if (!row)
            return

        ; Get script info
        scriptName := g_mainListView.GetText(row, 4)
        lineNumber := g_mainListView.GetText(row, 5)
        scriptPath := g_mainListView.GetText(row, 6)

        ; Try to open script
        if (scriptPath && FileExist(scriptPath)) {
            OpenScript(scriptPath, scriptName, lineNumber)
        } else {
            MsgBox("Script path not found: " scriptPath, "Error", "0x10")
        }
    } catch as err {
        logToFile("ERROR in OnMenuEditScript: " err.Message)
    }
}

;================= End of GuiContextMenu =================