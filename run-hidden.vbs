' Runs a PowerShell script with no window at all.
' powershell.exe -WindowStyle Hidden still flashes a console briefly; wscript does not.
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & WScript.Arguments(0) & """", 0, True
