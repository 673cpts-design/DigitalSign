# Kill Edge processes silently
Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# Relaunch Edge in kiosk mode with loading page
$edgeArguments = @(
    "--kiosk"
    "c:\www\loading.html"
    "--edge-kiosk-type=fullscreen"
    "--disable-pinch"
    "--touch-events=disabled"
    "--overscroll-history-navigation=0"
    "--disable-touch-drag-drop"
    "--disable-gesture-requirement-for-media-playback"
    "--disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
)
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments
# Download google slides and convert to .png files
& "C:\www\scripts\DL-PDF2PNG.ps1"
# Use the quarterly images to build the html files for the cubes 
& "C:\www\scripts\Build-cube-html.ps1"
# Use the yearly images to buils the html files for the yearly slides
& "C:\www\scripts\Build-year-html.ps1"
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
    "c:\www\index.html"
    "--edge-kiosk-type=fullscreen"
    "--disable-pinch"
    "--touch-events=disabled"
    "--overscroll-history-navigation=0"
    "--disable-touch-drag-drop"
    "--disable-gesture-requirement-for-media-playback"
    "--disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
)
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments
