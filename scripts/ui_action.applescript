on run argv
 set operation to item 1 of argv
 set targetID to item 2 of argv
 tell application "System Events" to tell process "Campus"
  set frontmost to true
  set elementsList to {}
  repeat with w in windows
   set elementsList to elementsList & entire contents of w
  end repeat
  repeat with e in elementsList
   try
    if value of attribute "AXIdentifier" of e is targetID then
     if operation is "click" and role of e is "AXButton" then
      if enabled of e is false then error "Control is disabled"
      perform action "AXPress" of e
      return "PASS click " & targetID
     else if operation is "type" and role of e is "AXTextField" then
      set value of attribute "AXFocused" of e to true
      set value of e to item 3 of argv
      key code 48
      return "PASS type " & targetID
     else if operation is "read" and role of e is "AXTextField" then
      return value of e
     end if
    end if
   end try
  end repeat
  error "Accessible control not found: " & targetID
 end tell
end run
