# Silently stop all Edge browser processes
$edgeProcs = Get-Process "msedge" -ErrorAction SilentlyContinue
if ($edgeProcs) {
    $edgeProcs | Stop-Process -Force
}

# Optional: Clear session restore files (safe cleanup)
$sessionPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Sessions\*"
Remove-Item $sessionPath -Force -ErrorAction SilentlyContinue

# Wait 5 seconds
Start-Sleep -Seconds 5

Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -ArgumentList "--kiosk c:\www\closed.html --edge-kiosk-type=fullscreen --disable-pinch --touch-events=disabled --overscroll-history-navigation=0 --disable-touch-drag-drop --disable-gesture-requirement-for-media-playback --disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
