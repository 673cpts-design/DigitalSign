Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -ArgumentList '--kiosk "file:///C:/www/index.html" --edge-kiosk-type=fullscreen --autoplay-policy=no-user-gesture-required --disable-pinch --touch-events=disabled --overscroll-history-navigation=0 --disable-touch-drag-drop --disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop'
