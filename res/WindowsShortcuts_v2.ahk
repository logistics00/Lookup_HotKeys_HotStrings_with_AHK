;================= WindowsShortcuts v1.0.0 =================
; Windows Shortcut Keys reference module for AHKHotkeyStringLookup - provides
; comprehensive Windows shortcut reference with searchable GUI interface.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

; Explicitly declare global functions and variables used from other modules
global logToFile

; Function to show Windows Shortcuts GUI
ShowWindowsShortcuts() {
    logToFile("Opening Windows Shortcuts reference window")

    ; Create the categories and shortcuts data
    categoriesAndShortcuts := CreateShortcutsData()

    ; Create the GUI
    shortcutGui := Gui("+Resize", "Windows Shortcut Keys Reference")
    shortcutGui.SetFont("s10", "Consolas")  ; Monospace font for better alignment

    ; Build the complete text content with all categories
    allContent := BuildAllCategoriesText(categoriesAndShortcuts)

    ; Add single read-only Edit control for all content
    mainEdit := shortcutGui.Add("Edit", "x10 y10 w780 h500 ReadOnly VScroll", allContent)

    ; Add search controls at the bottom
    shortcutGui.Add("Text", "x10 y520", "Search:")
    searchBox := shortcutGui.Add("Edit", "x70 y520 w200 h25")
    searchButton := shortcutGui.Add("Button", "x280 y520 w80", "Search")
    clearButton := shortcutGui.Add("Button", "x370 y520 w80", "Clear")

    ; Add explanation text
    shortcutGui.Add("Text", "x460 y525 w300", "* Shortcuts may vary by Windows version")

    ; Store original content for search functionality
    originalContent := allContent

    ; Define search function
    SearchFunc() {
        searchTerm := Trim(searchBox.Value)
        logToFile("Searching for: '" searchTerm "'")

        if (searchTerm = "") {
            ; If search is empty, restore original content
            mainEdit.Value := originalContent
            logToFile("Search cleared - restored original content")
        } else {
            ; Build filtered content based on search term
            filteredContent := BuildFilteredContent(categoriesAndShortcuts, searchTerm)
            mainEdit.Value := filteredContent
            logToFile("Search completed for: " searchTerm)
        }
    }

    ; Define resize function
    ResizeFunc(thisGui, minMax, width, height) {
        if (minMax = -1)  ; If window is minimized
            return

        ; Resize main edit control
        mainEdit.Move(,, width - 20, height - 80)

        ; Move search controls to bottom
        searchY := height - 55
        shortcutGui["Static1"].Move(, searchY)      ; "Search:" label
        searchBox.Move(, searchY)
        searchButton.Move(, searchY)
        clearButton.Move(, searchY)
        shortcutGui["Static2"].Move(, searchY + 5)  ; Explanation text
    }

    ; Define helper functions for events
    DelayedSearchFunc() {
        SetTimer(SearchFunc, -300)
    }

    ClearSearchFunc() {
        searchBox.Value := ""
        SearchFunc()
    }

    ; Connect events
    searchButton.OnEvent("Click", (*) => SearchFunc())
    searchBox.OnEvent("Change", (*) => DelayedSearchFunc())
    clearButton.OnEvent("Click", (*) => ClearSearchFunc())
    shortcutGui.OnEvent("Size", ResizeFunc)

    ; Show the GUI
    shortcutGui.Show("w800 h580")

    logToFile("Windows Shortcuts GUI displayed with single scrollable list")
}

; Function to build complete text content with all categories
BuildAllCategoriesText(categoriesAndShortcuts) {
    allContent := ""

    ; Add each category with header
    for category, shortcuts in categoriesAndShortcuts {
        ; Add category header
        allContent .= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`r`n"
        allContent .= "  " . StrUpper(category) . "`r`n"
        allContent .= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`r`n`r`n"

        ; Add shortcuts for this category
        allContent .= BuildCategoryText(shortcuts, false) ; Don't add extra spacing
        allContent .= "`r`n`r`n"  ; Add spacing between categories
    }

    return allContent
}

; Function to build filtered content based on search term
BuildFilteredContent(categoriesAndShortcuts, searchTerm) {
    if (searchTerm = "") {
        return BuildAllCategoriesText(categoriesAndShortcuts)
    }

    filteredContent := ""
    hasResults := false

    ; Search each category
    for category, shortcuts in categoriesAndShortcuts {
        categoryResults := []

        ; Filter shortcuts that match the search term
        for shortcut in shortcuts {
            if (InStr(shortcut.key, searchTerm, false) || InStr(shortcut.desc, searchTerm, false)) {
                categoryResults.Push(shortcut)
            }
        }

        ; If this category has results, add it to filtered content
        if (categoryResults.Length > 0) {
            hasResults := true

            ; Add category header
            filteredContent .= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`r`n"
            filteredContent .= "  " . StrUpper(category) . " (Found " . categoryResults.Length . " matches)`r`n"
            filteredContent .= "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`r`n`r`n"

            ; Add matching shortcuts
            filteredContent .= BuildCategoryText(categoryResults, false)
            filteredContent .= "`r`n`r`n"
        }
    }

    if (!hasResults) {
        filteredContent := "No shortcuts found matching '" . searchTerm . "'`r`n`r`nTry searching for:`r`n"
        filteredContent .= "• Key combinations (e.g., 'Win', 'Ctrl', 'Alt')`r`n"
        filteredContent .= "• Actions (e.g., 'copy', 'paste', 'screenshot')`r`n"
        filteredContent .= "• Applications (e.g., 'Explorer', 'Task Manager')`r`n"
    }

    return filteredContent
}

; Function to build formatted text content for a category
BuildCategoryText(shortcuts, addSpacing := true) {
    if (shortcuts.Length = 0) {
        return "No shortcuts available.`r`n"
    }

    textContent := ""

    ; Find the maximum key length for alignment
    maxKeyLength := 0
    for shortcut in shortcuts {
        if (StrLen(shortcut.key) > maxKeyLength) {
            maxKeyLength := StrLen(shortcut.key)
        }
    }

    ; Ensure minimum padding (but reasonable maximum)
    if (maxKeyLength < 25) {
        maxKeyLength := 25
    } else if (maxKeyLength > 35) {
        maxKeyLength := 35
    }

    ; Build the formatted text
    for shortcut in shortcuts {
        ; Pad the key to align descriptions
        paddedKey := shortcut.key
        while (StrLen(paddedKey) < maxKeyLength) {
            paddedKey .= " "
        }

        textContent .= paddedKey . " - " . shortcut.desc . "`r`n"
    }

    return textContent
}

; Function to create shortcut data
CreateShortcutsData() {
    data := Map()

    ; Keep the order logical - start with most common
    data["General Windows"] := [
        {key: "Win", desc: "Open or close Start menu"},
        {key: "Win + A", desc: "Open Action center/Notification center"},
        {key: "Win + B", desc: "Set focus to the notification area"},
        {key: "Win + C", desc: "Open Chat from taskbar (Teams/Microsoft 365)"},
        {key: "Win + D", desc: "Display and hide the desktop"},
        {key: "Win + E", desc: "Open File Explorer"},
        {key: "Win + F", desc: "Open Feedback Hub"},
        {key: "Win + G", desc: "Open Xbox Game Bar"},
        {key: "Win + H", desc: "Open the Share charm/dialog"},
        {key: "Win + I", desc: "Open Settings"},
        {key: "Win + K", desc: "Open the Connect quick action"},
        {key: "Win + L", desc: "Lock your PC or switch accounts"},
        {key: "Win + M", desc: "Minimize all windows"},
        {key: "Win + O", desc: "Lock device orientation"},
        {key: "Win + P", desc: "Choose a presentation display mode"},
        {key: "Win + Q", desc: "Open search"},
        {key: "Win + R", desc: "Open the Run dialog box"},
        {key: "Win + S", desc: "Open search"},
        {key: "Win + T", desc: "Cycle through apps on the taskbar"},
        {key: "Win + U", desc: "Open Accessibility/Ease of Access Center"},
        {key: "Win + V", desc: "Open the clipboard history"},
        {key: "Win + W", desc: "Open Windows Widgets/News and interests"},
        {key: "Win + X", desc: "Open the Quick Link/Power User menu"},
        {key: "Win + Z", desc: "Open the snap layouts"},
        {key: 'Win + ,', desc: "Temporarily peek at the desktop"},
        {key: "Win + .", desc: "Open emoji panel"},
        {key: 'Win + `;', desc: "Open emoji panel"},
        {key: "Win + +", desc: "Zoom in using Magnifier"},
        {key: "Win + -", desc: "Zoom out using Magnifier"},
        {key: "Win + Esc", desc: "Close Magnifier"}
    ]

    data["Window Management"] := [
        {key: "Win + Tab", desc: "Open Task View/timeline"},
        {key: "Win + Home", desc: "Minimize all but the active window"},
        {key: "Win + Shift + M", desc: "Restore minimized windows to the desktop"},
        {key: "Win + Up", desc: "Maximize the window"},
        {key: "Win + Down", desc: "Minimize or restore the window"},
        {key: "Win + Left", desc: "Snap window to left side"},
        {key: "Win + Right", desc: "Snap window to right side"},
        {key: "Win + Shift + Up", desc: "Stretch window to top and bottom of screen"},
        {key: "Win + Shift + Left", desc: "Move window to left monitor"},
        {key: "Win + Shift + Right", desc: "Move window to right monitor"},
        {key: "Alt + Tab", desc: "Switch between open apps"},
        {key: "Alt + F4", desc: "Close the active window"}
    ]

    data["File Explorer"] := [
        {key: "Alt + D", desc: "Select the address bar"},
        {key: "Alt + P", desc: "Display the preview panel"},
        {key: "Alt + Enter", desc: "Open Properties for the selected item"},
        {key: "Alt + Up", desc: "View the folder one level up"},
        {key: "Ctrl + N", desc: "Open a new window"},
        {key: "Ctrl + E", desc: "Select the search box"},
        {key: "Ctrl + F", desc: "Select the search box"},
        {key: "Ctrl + W", desc: "Close the current window"},
        {key: "Ctrl + Shift + E", desc: "Display all folders above selected folder"},
        {key: "Ctrl + Shift + N", desc: "Create a new folder"},
        {key: "F2", desc: "Rename selected item"},
        {key: "F5", desc: "Refresh the active window"},
        {key: "Delete", desc: "Move selected item to Recycle Bin"},
        {key: "Shift + Delete", desc: "Delete selected item permanently"}
    ]

    data["Taskbar & System"] := [
        {key: "Win + T", desc: "Cycle through taskbar items"},
        {key: "Win + 1-9", desc: "Open the app pinned to taskbar position"},
        {key: "Win + Alt + 1-9", desc: "Open Jump List for app in taskbar position"},
        {key: "Win + B", desc: "Highlight the notification area"},
        {key: "Shift + Click", desc: "Open a new instance of an app on taskbar"},
        {key: "Ctrl + Shift + Click", desc: "Open an app as administrator"},
        {key: "Shift + Right-click", desc: "Show window menu for the app"},
        {key: "Ctrl + Shift + Esc", desc: "Open Task Manager directly"},
        {key: "Ctrl + Alt + Delete", desc: "Open security options screen"},
        {key: "Win + Pause", desc: "Display the System Properties dialog box"}
    ]

    data["Web Browsers"] := [
        {key: "Ctrl + T", desc: "Open a new tab"},
        {key: "Ctrl + N", desc: "Open a new window"},
        {key: "Ctrl + W", desc: "Close the current tab"},
        {key: "Ctrl + Shift + T", desc: "Reopen the last closed tab"},
        {key: "Ctrl + Tab", desc: "Switch to the next tab"},
        {key: "Ctrl + Shift + Tab", desc: "Switch to the previous tab"},
        {key: "Alt + D", desc: "Select the URL in the address bar"},
        {key: "Ctrl + F", desc: "Find on page"},
        {key: "F11", desc: "Toggle full screen"},
        {key: "Ctrl + H", desc: "Open History"},
        {key: "Ctrl + J", desc: "Open Downloads"},
        {key: "Ctrl + Shift + B", desc: "Show/hide the favorites bar"},
        {key: "Ctrl + R", desc: "Refresh the page"},
        {key: "F5", desc: "Refresh the page"}
    ]

    data["Command Prompt"] := [
        {key: "Ctrl + C", desc: "Copy selected text or cancel command"},
        {key: "Ctrl + V", desc: "Paste text"},
        {key: "Ctrl + A", desc: "Select all text"},
        {key: "Ctrl + M", desc: "Enter Mark mode"},
        {key: "Alt + F4", desc: "Close the Command Prompt"},
        {key: "Up/Down Arrows", desc: "Scroll through command history"},
        {key: "F7", desc: "Display command history"},
        {key: "Alt + Enter", desc: "Toggle full screen mode"},
        {key: 'Win + X, C', desc: "Open Command Prompt from Quick Link menu"},
        {key: 'Win + X, A', desc: "Open PowerShell Admin from Quick Link menu"},
        {key: 'Ctrl + Shift + ``', desc: "New terminal tab (Windows Terminal)"},
        {key: "Alt + Shift + =", desc: "Split pane horizontally (Windows Terminal)"},
        {key: "Alt + Shift + -", desc: "Split pane vertically (Windows Terminal)"}
    ]

    data["Windows 11 Specific"] := [
        {key: "Win + Z", desc: "Open the snap layouts menu"},
        {key: "Win + Alt + Up", desc: "Snap active window to top half of screen"},
        {key: "Win + Ctrl + C", desc: "Turn on color filters (if enabled in settings)"},
        {key: "Win + Ctrl + D", desc: "Add a virtual desktop"},
        {key: "Win + Ctrl + F4", desc: "Close current virtual desktop"},
        {key: "Win + Ctrl + Left", desc: "Switch to previous virtual desktop"},
        {key: "Win + Ctrl + Right", desc: "Switch to next virtual desktop"},
        {key: "Win + Shift + Up", desc: "Stretch window to top of screen"},
        {key: "Win + Shift + Down", desc: "Stretch window to bottom of screen"},
        {key: "Win + Shift + N", desc: "Open notification settings"},
        {key: "Win + H", desc: "Open voice typing"},
        {key: "Win + Shift + S", desc: "Take screenshot with Snip & Sketch"}
    ]

    data["Accessibility"] := [
        {key: "Win + Ctrl + M", desc: "Start/stop Magnifier"},
        {key: "Win + Ctrl + N", desc: "Open Narrator settings"},
        {key: "Win + Ctrl + S", desc: "Turn on/off Windows Speech Recognition"},
        {key: "Win + Enter", desc: "Open Narrator"},
        {key: "Win + Ctrl + O", desc: "Turn on On-Screen Keyboard"},
        {key: "Win + U", desc: "Open Accessibility Settings"},
        {key: "Win + Shift + Spacebar", desc: "Switch input language/keyboard layout"},
        {key: "Win + +", desc: "Zoom in with Magnifier"},
        {key: "Win + -", desc: "Zoom out with Magnifier"},
        {key: "Right Shift (8 sec)", desc: "Toggle Filter Keys on/off"},
        {key: "Alt + Shift + Print Screen", desc: "Toggle High Contrast on/off"},
        {key: "Alt + Shift + Num Lock", desc: "Toggle Mouse Keys on/off"},
        {key: "Win + Ctrl + Enter", desc: "Turn Narrator on/off"}
    ]

    data["Special Features"] := [
        {key: "Win + Shift + S", desc: "Take a screenshot with Snipping Tool"},
        {key: "Win + Alt + R", desc: "Record screen with Xbox Game Bar"},
        {key: "Win + Alt + G", desc: "Record last 30 seconds with Game Bar"},
        {key: "Win + Period", desc: "Open emoji, GIF, and symbol picker"},
        {key: "Win + Ctrl + Q", desc: "Open Quick Assist"},
        {key: "Win + Ctrl + F", desc: "Search for PCs (on a network)"},
        {key: "Win + K", desc: "Connect to wireless displays and audio devices"},
        {key: "Win + Alt + K", desc: "Toggle microphone mute (Teams/conferencing)"},
        {key: "Win + Shift + C", desc: "Open Cortana in listening mode"},
        {key: "Print Screen", desc: "Copy screenshot to clipboard"},
        {key: "Alt + Print Screen", desc: "Copy active window screenshot"},
        {key: "Win + Print Screen", desc: "Save screenshot to Pictures folder"}
    ]

    return data
}

;================= End of WindowsShortcuts =================