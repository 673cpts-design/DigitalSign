# Close all Edge browser windows and reload Edge in KIOSK mode, refreshing the information/covering up popups
# Graceful Edge shutdown attempt by closing the windowed parent allows child processes to wind down naturally to -
# Prevents “Edge didn’t shut down correctly” banners.
# Profile stability: avoids corrupting session/lock files.
# Find the browser processes that actually own a window
# Close all Edge browser windows and reload Edge in KIOSK mode

# Graceful shutdown: Attempts to close only real windows first
foreach ($process in (Get-Process -Name "msedge" -ErrorAction SilentlyContinue)) {
    if ($process.MainWindowHandle -ne 0) {
        $null = $process.CloseMainWindow()  # suppress output
    }
}
# Small delay for graceful exit
Start-Sleep -Seconds 5
# Kill any leftover processes silently
Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# Clear session restore files to prevent warning banners
$sessionPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Sessions\*"
Remove-Item $sessionPath -Force -ErrorAction SilentlyContinue
# Relaunch Edge in kiosk mode
$edgeArguments = @(
    "--kiosk" 
    "c:\www\open.html"
    "--edge-kiosk-type=fullscreen"
    "--disable-pinch"
    "--touch-events=disabled"
    "--overscroll-history-navigation=0"
    "--disable-touch-drag-drop"
    "--disable-gesture-requirement-for-media-playback"
    "--disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
) 
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments