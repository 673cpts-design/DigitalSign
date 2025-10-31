# Silently closes Microsoft Edge gracefully if running, with a forced fallback if needed.
# If Edge is not running, skip close logic but continue with cleanup and relaunch.

# Check if Edge is running
$edgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue

if ($edgeProcesses) {
    # Define API to post a close message to window handles
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class WinAPI {
      [DllImport("user32.dll")]
      public static extern bool PostMessage(IntPtr hWnd, uint Msg, int wParam, int lParam);
    }
"@

    $WM_CLOSE = 0x0010

    # Attempt graceful close for all Edge windows
    foreach ($proc in $edgeProcesses) {
        try {
            if ($proc.MainWindowHandle -ne 0) {
                [WinAPI]::PostMessage($proc.MainWindowHandle, $WM_CLOSE, 0, 0) | Out-Null
            }
        } catch {
            # ignore any errors silently
        }
    }

    # Wait a few seconds for graceful shutdown
    Start-Sleep -Seconds 5

    # Force close remaining Edge processes if still running
    $stillRunning = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
    if ($stillRunning) {
        Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
    }
}

# Optional: Clear session restore files (safe cleanup)
$sessionPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Sessions\*"
Remove-Item $sessionPath -Force -ErrorAction SilentlyContinue

# Wait 5 seconds
Start-Sleep -Seconds 5

# Restart Edge in kiosk mode
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -ArgumentList "--kiosk c:\www\closed.html --edge-kiosk-type=fullscreen --disable-pinch --touch-events=disabled --overscroll-history-navigation=0 --disable-touch-drag-drop --disable-gesture-requirement-for-media-playback --disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"

exit 0
