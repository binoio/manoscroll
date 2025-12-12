-- check_close_menu.applescript
-- Returns ENABLED if File > Close is enabled, DISABLED otherwise
-- Run with: osascript check_close_menu.applescript

set appName to "ManoScroll"

-- Activate the app
try
    tell application appName to activate
on error errMsg
    -- If app isn't running, try opening the bundled app
    try
        do shell script "open ./ManoScroll.app"
        delay 0.8
    end try
end try

-- Give the app time to settle
delay 0.6

try
    tell application "System Events"
        -- Ensure the app's process exists
        if not (exists process appName) then
            return "ERROR: process_not_found"
        end if
        tell process appName
            -- Open the File menu
            set fileItem to menu bar 1's menu bar item "File"
            click fileItem
            delay 0.15
            -- Get the Close menu item
            set closeItem to menu item "Close" of menu 1 of fileItem
            set isEnabled to enabled of closeItem
            -- Dismiss the menu
            keystroke (ASCII character 27)
            if isEnabled then
                return "ENABLED"
            else
                return "DISABLED"
            end if
        end tell
    end tell
on error errMsg number errNum
    return "ERROR: " & errMsg
end try
