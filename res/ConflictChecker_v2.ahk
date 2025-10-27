;================= ConflictChecker v1.0.0 =================
; Windows shortcut conflict detection - checks script hotkeys against Windows
; built-in shortcuts and provides conflict status information with detailed
; classification of exact vs potential conflicts.

#Requires AutoHotkey v2.0.2+
#SingleInstance Force

#Include CoreModule_v2.ahk
moduleCore := CoreModule()

#Include WindowsShortcuts_v2.ahk
shortcutsWindows := WindowsShortcuts()

; Explicitly declare global functions and variables used from other modules
; NMS Next staytement commented after #Include CoreModule.ahk2
; global logToFile

Class ConflictCheckers {
    ; New : 25-01-24
    ; GetWindowsShortcutsList : () : Get all Windows shortcuts as a flat list for conflict checking
    ; Returns : Map - Map of normalized Windows shortcuts with key, description, and category
    GetWindowsShortcutsList() {
        ; NMS 1 line added
        moduleCore.logToFile(' =============ConflictCheckers / GetWindowsShortcutsList =============', 'NMS')
        ; Get the shortcuts data from WindowsShortcuts.ahk
        categoriesAndShortcuts := shortcutsWindows.CreateShortcutsData()

        windowsShortcuts := Map()

        ; Flatten all categories into a single map for quick lookup
        for category, shortcuts in categoriesAndShortcuts {
            for shortcut in shortcuts {
                ; Normalize the key format for comparison
                normalizedKey := this.NormalizeHotkeyFormat(shortcut.key)
                if (normalizedKey.normalized != '') {
                    windowsShortcuts[normalizedKey.normalized] := {
                        key: shortcut.key,
                        desc: shortcut.desc,
                        category: category
                    }
                }
            }
        }

        moduleCore.logToFile('Loaded ' windowsShortcuts.Count ' Windows shortcuts for conflict detection')
        return windowsShortcuts
    }

    ; New : 25-01-24
    ; NormalizeHotkeyFormat : (hotkeyStr) : Normalize hotkey format for consistent comparison
    ; hotkeyStr : string - Hotkey string to normalize
    ; Returns : object - Object with original and normalized hotkey strings
    NormalizeHotkeyFormat(hotkeyStr) {
        ; NMS 1 line added
        moduleCore.logToFile(' =============ConflictCheckers / NormalizeHotkeyFormat ===============', 'NMS')
        if (!hotkeyStr)
            return {original: '', normalized: ''}

        ; Keep the original string for exact comparison, but also create normalized version
        original := hotkeyStr
        normalized := hotkeyStr

        ; Don't modify qualifiers like ~, $, <, > - they're important for comparison
        ; Only normalize text representations to AHK format

        ; Handle 'Win' prefix but preserve other qualifiers
        normalized := RegExReplace(normalized, 'i)\bWin\s*\+\s*', '#')
        normalized := RegExReplace(normalized, 'i)\bWin\s+', '#')
        ; Don't replace standalone 'Win' as it might be part of a qualifier

        ; Handle modifier keys but preserve their position and qualifiers
        normalized := RegExReplace(normalized, 'i)\bCtrl\s*\+\s*', '^')
        normalized := RegExReplace(normalized, 'i)\bAlt\s*\+\s*', '!')
        normalized := RegExReplace(normalized, 'i)\bShift\s*\+\s*', '+')

        ; Handle special key names (but keep qualifiers intact)
        normalized := RegExReplace(normalized, 'i)\bPrint Screen\b', 'PrintScreen')
        normalized := RegExReplace(normalized, 'i)\bNum Lock\b', 'NumLock')
        normalized := RegExReplace(normalized, 'i)\bCaps Lock\b', 'CapsLock')
        normalized := RegExReplace(normalized, 'i)\bPage Up\b', 'PgUp')
        normalized := RegExReplace(normalized, 'i)\bPage Down\b', 'PgDn')

        ; Handle arrow keys
        normalized := RegExReplace(normalized, 'i)\bUp Arrow\b', 'Up')
        normalized := RegExReplace(normalized, 'i)\bDown Arrow\b', 'Down')
        normalized := RegExReplace(normalized, 'i)\bLeft Arrow\b', 'Left')
        normalized := RegExReplace(normalized, 'i)\bRight Arrow\b', 'Right')

        ; Handle ranges like 'Win + 1-9' - create base pattern
        match := ''
        if (RegExMatch(normalized, 'i)(.+)\s+(\d)\s*-\s*(\d)', &match)) {
            normalized := match[1]
        }

        ; Remove extra spaces but preserve qualifier structure
        normalized := RegExReplace(normalized, '\s+', '')

        return {original: original, normalized: normalized}
    }

    ; New : 25-01-24
    ; ParseHotkey : (hotkeyStr) : Extract modifiers and base key from hotkey
    ; hotkeyStr : string - Hotkey string to parse
    ; Returns : object - Object with qualifiers, modifiers, baseKey, and full hotkey
    ParseHotkey(hotkeyStr) {
        ; NMS 1 line added
        moduleCore.logToFile(' =============ConflictCheckers / ParseHotkey ===============', 'NMS')
        if (!hotkeyStr)
            return {qualifiers: '', modifiers: '', baseKey: ''}

        ; Extract qualifiers (~, $, <, >, etc.)
        qualifiers := ''
        match := ''
        if (RegExMatch(hotkeyStr, '^([~$<>*]+)', &match))
            qualifiers := match[1]

        ; Remove qualifiers to get the rest
        withoutQualifiers := RegExReplace(hotkeyStr, '^[~$<>*]+', '')

        ; Extract modifiers (^, !, +, #)
        modifiers := ''
        baseKey := withoutQualifiers

        ; Extract modifiers one by one
        replaceCount := 0
        if (InStr(baseKey, '^')) {
            modifiers .= '^'
            baseKey := StrReplace(baseKey, '^', '', false, &replaceCount, 1)
        }
        if (InStr(baseKey, '!')) {
            modifiers .= '!'
            baseKey := StrReplace(baseKey, '!', '', false, &replaceCount, 1)
        }
        if (InStr(baseKey, '+')) {
            modifiers .= '+'
            baseKey := StrReplace(baseKey, '+', '', false, &replaceCount, 1)
        }
        if (InStr(baseKey, '#')) {
            modifiers .= '#'
            baseKey := StrReplace(baseKey, '#', '', false, &replaceCount, 1)
        }

        return {
            qualifiers: qualifiers,
            modifiers: modifiers,
            baseKey: baseKey,
            full: hotkeyStr
        }
    }

    ; New : 25-01-24
    ; CheckHotkeyConflict : (scriptHotkey) : Check if a script hotkey conflicts with Windows shortcuts
    ; scriptHotkey : string - Hotkey to check for conflicts
    ; Returns : object|bool - Conflict information object or false if no conflict
    CheckHotkeyConflict(scriptHotkey) {
        ; NMS 1 line added
        moduleCore.logToFile(' =============ConflictCheckers / CheckHotkeyConflict ===============', 'NMS')
        static windowsShortcuts := ''

        ; Initialize shortcuts list on first call
        if (!windowsShortcuts) {
            windowsShortcuts := this.GetWindowsShortcutsList()
        }

        ; Parse the script hotkey
        scriptParsed := this.ParseHotkey(scriptHotkey)

        if (!scriptParsed.baseKey)
            return false

        ; Check against Windows shortcuts
        for winKey, winShortcut in windowsShortcuts {
            winParsed := this.ParseHotkey(winKey)

            ; For exact conflict: modifiers and base key must match exactly
            ; Qualifiers like ~, $, < etc. make it NOT a conflict (they modify behavior)
            if (scriptParsed.qualifiers = '' &&
                scriptParsed.modifiers = winParsed.modifiers &&
                scriptParsed.baseKey = winParsed.baseKey) {

                moduleCore.logToFile('EXACT CONFLICT: ' scriptHotkey ' conflicts with Windows shortcut: ' winShortcut.key ' (' winShortcut.desc ')')
                return {
                    isConflict: true,
                    isExact: true,
                    windowsKey: winShortcut.key,
                    windowsDesc: winShortcut.desc,
                    category: winShortcut.category
                }
            }

            ; For potential conflict: base key matches but modifiers differ
            ; Still only if no qualifiers (qualifiers prevent conflicts)
            if (scriptParsed.qualifiers = '' &&
                scriptParsed.baseKey = winParsed.baseKey &&
                scriptParsed.modifiers != winParsed.modifiers) {

                moduleCore.logToFile('POTENTIAL CONFLICT: ' scriptHotkey ' may interfere with Windows shortcut: ' winShortcut.key)
                return {
                    isConflict: true,
                    isPotential: true,
                    windowsKey: winShortcut.key,
                    windowsDesc: winShortcut.desc,
                    category: winShortcut.category
                }
            }
        }

        return false
    }

    ; New : 25-01-24
    ; IsHotkeyRelated : (hotkey1, hotkey2) : Check if two hotkeys are related (similar modifier combinations)
    ; hotkey1 : string - First hotkey to compare
    ; hotkey2 : string - Second hotkey to compare
    ; Returns : bool - True if hotkeys are related
    IsHotkeyRelated(hotkey1, hotkey2) {
        ; NMS 1 line added
        moduleCore.logToFile(' =============ConflictCheckers / IsHotkeyRelated ===============', 'NMS')
        ; Simple check for now - can be enhanced
        ; Check if one hotkey is contained within another (ignoring case)
        if (InStr(hotkey1, hotkey2, false) || InStr(hotkey2, hotkey1, false)) {
            return true
        }

        return false
    }

    ; New : 25-01-24
    ; GetConflictStatusText : (conflictInfo) : Get conflict status text for display
    ; conflictInfo : object - Conflict information object
    ; Returns : string - Formatted conflict status text
    GetConflictStatusText(conflictInfo) {
        ; NMS 1 line added
        moduleCore.logToFile(' =============ConflictCheckers / GetConflictStatusText ===============', 'NMS')
        ; Debug logging to confirm function call
        try {
            moduleCore.logToFile('Called GetConflictStatusText with conflictInfo: ' (IsObject(conflictInfo) ? 'valid' : 'invalid'))
        } catch {
            OutputDebug('Called GetConflictStatusText with conflictInfo: ' (IsObject(conflictInfo) ? 'valid' : 'invalid'))
        }

        if (!conflictInfo || !conflictInfo.isConflict)
            return ''

        ; Return cleaner text without emojis, as GuiListView adds its own
        if (conflictInfo.HasOwnProp('isExact') && conflictInfo.isExact)
            return 'with ' conflictInfo.windowsKey ' (' conflictInfo.windowsDesc ')'
        else if (conflictInfo.HasOwnProp('isPotential') && conflictInfo.isPotential)
            return 'with ' conflictInfo.windowsKey ' (' conflictInfo.windowsDesc ')'
        else
            return 'with ' conflictInfo.windowsKey ' (' conflictInfo.windowsDesc ')'
    }

    ; New : 25-01-24
    ; GetConflictIcon : (conflictInfo) : Get conflict icon for ListView
    ; conflictInfo : object - Conflict information object
    ; Returns : int - Icon index (1=default, 3=warning, 4=error)
    GetConflictIcon(conflictInfo) {
        ; NMS 1 line added
        moduleCore.logToFile(' =============ConflictCheckers / GetConflictIcon ===============', 'NMS')
        if (!conflictInfo || !conflictInfo.isConflict)
            return 1  ; Default icon

        if (conflictInfo.HasOwnProp('isPotential') && conflictInfo.isPotential)
            return 3  ; Warning icon
        else
            return 4  ; Error/conflict icon
    }
}
;================= End of ConflictChecker =================
