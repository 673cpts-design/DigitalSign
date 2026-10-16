& "C:\QwenVoice\Update-Announcement.ps1"
$edgeArguments = @(
    "--kiosk" 
    "c:\www\closed.html"
    "--edge-kiosk-type=fullscreen"
    "--overscroll-history-navigation=0"
    "--autoplay-policy=no-user-gesture-required"
) 
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments
