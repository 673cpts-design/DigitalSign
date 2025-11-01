Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\www\scripts\RSS.ps1""", 0, True
