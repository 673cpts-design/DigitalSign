Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -ArgumentList "--kiosk c:\www\index.html --edge-kiosk-type=fullscreen --disable-pinch --touch-events=disabled --overscroll-history-navigation=0 --disable-touch-drag-drop --disable-gesture-requirement-for-media-playback --disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
