TOP-RIGHT PICTURE AND VIDEO SLIDESHOW

INSTALL
Extract this ZIP directly into C:\www, preserving the scripts subfolder.
Requires PowerShell 7.2 or later for the builder/watcher.
The package does not replace your existing index.html or Awards builder.
Swiper 11.2.10 is bundled from your Awards project; no CDN or runtime downloads.

1. Put pictures/videos into C:\www\pictures, or let the Pixel importer do that.
2. Run Watch-Media-Folder.cmd and leave it running.
3. Open C:\www\media-slideshow.html in Edge, full screen.

The generated page is already included with an empty playlist. The watcher
builds the playlist immediately and updates it as files arrive or disappear.
Build-Once.cmd is also included for a fixed playlist without a running watcher.
After restarting Windows, run the watcher again (scheduling can be added later).

LAYOUT AND EFFECT
- Full page: 3840 x 2160 landscape, or proportional to the current viewport.
- Media area: TOP RIGHT, x=1920, y=0, width=1920, height=1080 at 4K.
- Remaining three quadrants and unused space around media are transparent.
- Media uses object-fit:contain: centered, correct aspect ratio, no cropping.
- Same Swiper 11 + SwiperGL random WebGL effects and 1200ms speed as the
  absolute bottom-left Who panel (x=50, y=1235) in the Awards builder.
- The black Who-panel background is removed. Transparent letterboxing is used,
  with a transparency mask for shaders that would otherwise force opacity. No arrows, controls or touch navigation.
- Pictures: two full seconds after decoding and after their entrance transition.
  The 1200ms WebGL transition is additional; change the 2000 value in
  media-slideshow.js to adjust picture duration. Transition speed is 1200ms
  with a 1250ms completion wait in the same script.
- Videos: restart at the beginning, play muted to the end, then advance.
  Muting permits normal unattended browser autoplay. Existing Edge policy must
  also permit autoplay. No audio playback is enabled by this package.
- One picture stays visible; one video repeats. Empty folder stays transparent.
- Playlist is ordered by full filename/path, with subfolders included.
- Importer staging/log files in .phone-import are excluded.
- New files are discovered within about 10 seconds, then applied at the next
  picture/video boundary. A new playlist restarts from its first entry.
  A playing video is not interrupted just to add files.

ADDING TO YOUR EXISTING SIGN
Use a full-page iframe, because the child already positions itself top-right:

<iframe
  src="media-slideshow.html"
  title="Pictures and videos"
  style="position:fixed;inset:0;width:100vw;height:100vh;border:0;background:transparent;pointer-events:none;z-index:112;"
></iframe>

Use an appropriate z-index for your existing page. Do NOT make the iframe itself
one quadrant wide/high; that would make this slideshow a quarter of a quarter.
Transparent HTML reveals the parent page when embedded. A standalone browser
tab may display its own white backing; it does not reveal the Windows desktop.
Any black bars baked into a picture/video remain part of that file.

OFFLINE OPERATION
Playback and building work via file://. A small local JavaScript playlist is
reloaded every five seconds. No fetch, web server or Internet is needed.
Keep media-slideshow.html and media-playlist.js in C:\www and the scripts in
C:\www\scripts. Your usual Edge --allow-file-access-from-files kiosk setting
may be retained. This package does not change any Edge policy or launch flags.

FORMATS AND FAILURES
JPEG/PNG/WebP and Edge-compatible MP4/WebM are the most portable choices.
MOV playback depends on its actual codec. HEIC/HEIF, TIFF/DNG, HEVC video and
other formats depend on browser/Windows codec support and may require conversion.
The importer preserves originals; this slideshow does NOT transcode anything.
All configured media types are attempted, but files the browser cannot decode
are skipped with a console warning rather than stopping the slideshow.
A video with no playback progress for 30 seconds is skipped. This is a stall
timeout, not a maximum video duration. An all-unplayable playlist stays blank
and retries after 30 seconds. Zero-byte files are excluded by the builder.

CUSTOM LOCATIONS
pwsh -NoProfile -File C:\www\scripts\Build-Media-Slideshow.ps1 -RootPath C:\www -MediaFolder D:\Media -Watch

SOURCE AND LICENSE
Adapted from the absolute bottom-left #who-panel (NOT quarter-1) in:
https://github.com/673cpts-design/DigitalSign/blob/main/CPTS.Awards/scripts/Build-Index-Html.ps1
Bundled Swiper JS and CSS are the versions from that same scripts directory.
Swiper copyright Vladimir Kharlampidi; MIT license (see scripts/SWIPER-LICENSE.txt).

VALIDATION
Tested in headless Chromium using local file:// playback: 4K static layout
and transparent margins; 1080p WebGL animation, image/video sequencing,
video-ended advancement, single-video repeat and playlist replacement.
PowerShell builder tested with empty and mixed-media folders.
Final Windows Edge codec support depends on the media files and installed codecs.

GL TRANSITION IMPLEMENTATION
The original SwiperGL engine and random shader selection are preserved.
It uses two reusable transparent 1920x1080 textures. Videos play as native video
elements; their last decoded frame participates in the outgoing GL transition,
and the next item's first frame participates in the incoming transition.
This avoids asking an image-only GL plugin to decode video URLs.
A runtime alpha mask keeps empty texture margins transparent, including shaders
which originally force an opaque output. Original GL vendor files are unchanged.
If WebGL is unavailable, playback falls back to direct media changes.
SwiperGL remains under UI Initiative's Regular License, as noted in its original
header. It is the dependency from your existing project, not MIT-licensed Swiper.
