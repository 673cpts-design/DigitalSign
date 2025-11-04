Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\www\scripts\git-it.ps1""", 0, True
