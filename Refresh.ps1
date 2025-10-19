# Close all Edge browser windows and reload Edge in KIOSK mode, refreshing the information/covering up popups
# Graceful Edge shutdown attempt by closing the windowed parent allows child processes to wind down naturally to -
# Prevents “Edge didn’t shut down correctly” banners.
# Profile stability: avoids corrupting session/lock files.


# Find the browser processes that actually own a window
for $process in (Get-Process -Name "msedge" -ErrorAction SilentlyContinue) {
    if ($process.MainWindowHandle -ne 0) {
        $process.CloseMainWindow()
        # wait here if you want
    $process.Close()  # close all the processes, not just the one that has the mainwindow
}
# Kill any extra left overs
Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue


#Clear session restore files (safe cleanup)
$sessionPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Sessions\*"
Remove-Item $sessionPath -Force -ErrorAction SilentlyContinue

# Wait 5 seconds
Start-Sleep -Seconds 5

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

exit 0