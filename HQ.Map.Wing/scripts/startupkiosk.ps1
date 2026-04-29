# Clear session restore files to prevent warning banners
$sessionPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Sessions\*"
Remove-Item $sessionPath -Force -ErrorAction SilentlyContinue

# Relaunch Edge in kiosk mode
$edgeArguments = @(
    "--kiosk c:\www\index.html"
    "--edge-kiosk-type=fullscreen"
    "--disable-pinch"
    "--touch-events=disabled"
    "--overscroll-history-navigation=0"
    "--disable-touch-drag-drop"
    "--disable-gesture-requirement-for-media-playback"
    "--disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
)

Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments
