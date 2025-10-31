Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -File ""C:\www\scripts\openrefresh.ps1""", 0, False