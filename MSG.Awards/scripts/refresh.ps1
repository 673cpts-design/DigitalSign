#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#-------------------------------Kiosk Data Refresh Script----------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------


# ------------------------- Set Edge arguments for each launch ----------------------------------
# 1 Edge arguments for loading.
# 2 Edge argumnets for main page.

# 1 Edge arguments for loading.
$edgeArguments1 = @(
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
# 2 Edge argumnets for main page.
$edgeArguments2 = @(
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

# ------------------------- Quickly display a loading page for button press feedback ----------------------------------
# 1 Kill Edge processes fast and silently so the feedback from the button press is instant. 
# 2 Relaunch Edge in kiosk mode with loading page
# 1 Kill Edge processes fast and silently so the feedback from the button press is instant. 
Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# 2 Relaunch Edge in kiosk mode with loading page
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments1


# ------------------------- Download content from user made Google slides presentations & convert from PDF to PNG ----------------------------------
# Download google slides and convert to .png files
& "C:\www\scripts\DL-PDF2PNG.ps1"


# ------------------------- Build html files for each slideshow based on the generated PNG files (previous step) ----------------------------------
# Use the quarterly images to build the html files for the cubes 
& "C:\www\scripts\Build-cube-html.ps1"
# Use the yearly images to buils the html files for the yearly slides
& "C:\www\scripts\Build-year-html.ps1"
# Use the who images to buils the html files for the who are we slides
& "C:\www\scripts\Build-card-html.ps1"


# ------------------------- Close Edge and reload the main display html ----------------------------------
# 1 Close Edge gracefully.
# 2 Give it time for Edge graceful exit. 
# 3 Force Edge to close if it is stuck.
# 4 Clear Edge session restore files to prevent warning banners.
#5 Relaunch Edge in kiosk mode with refreshed data

# 1 Graceful shutdown
foreach ($process in (Get-Process -Name "msedge" -ErrorAction SilentlyContinue)) {
    if ($process.MainWindowHandle -ne 0) {
        $null = $process.CloseMainWindow()  # suppress output
    }
}
#2 Give it time for Edge graceful exit. 
Start-Sleep -Seconds 10
# 3 Force Edge to close if it is stuck.
Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# 4 Clear Edge session restore files to prevent warning banners.
$sessionPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Sessions\*"
Remove-Item $sessionPath -Force -ErrorAction SilentlyContinue
#5 Relaunch Edge in kiosk mode with refreshed data
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments2
