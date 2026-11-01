# Refresh all presentation content while the existing Edge kiosk keeps playing.
# DL-PDF2PNG.ps1 publishes the completion signal itself after successful conversion.
$ErrorActionPreference = 'Stop'
& "C:\www\scripts\DL-PDF2PNG.ps1"
