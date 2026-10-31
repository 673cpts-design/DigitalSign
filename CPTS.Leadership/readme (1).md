# CPTS Leadership

A local, full-screen digital sign for leadership information, community media, office contacts, and installation updates. Built for a **3840 × 2160 landscape display**, this project combines eight leadership portraits with an animated American flag, a mixed photo/video slideshow, and an Air Force blue information board.

Content owners maintain Google Slides and Google Sheets. PowerShell downloads and prepares their content; Microsoft Edge displays the resulting local files. **No web server is required.**

> Playback uses local files. Internet access is required to retrieve new Google content, JBERLife events, Air Force Times headlines, or repository updates. WhatsApp requires its own connectivity to receive submissions; USB import itself uses ADB.

## Contents

- [What appears on screen](#what-appears-on-screen)
- [How the project works](#how-the-project-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Editing the content](#editing-the-content)
- [Refresh and button operation](#refresh-and-button-operation)
- [Script reference](#script-reference)
- [Local files and update intervals](#local-files-and-update-intervals)
- [Customization](#customization)
- [Maintenance and troubleshooting](#maintenance-and-troubleshooting)
- [Credits and dependencies](#credits-and-dependencies)

## What appears on screen

### Leadership display

Eight fixed portrait panels occupy the left side of the display. Each panel is **528 × 660 pixels**. Three are across the top, two flank the center logo, and three run along the bottom. These are fixed image positions, not rotating cubes or a leadership slideshow.

The official logo sits between the middle portraits. A smaller blue panel beneath it displays the computer's local time, weekday, and date. Time always uses a **24-hour clock with seconds**, regardless of the Windows 12/24-hour preference.

### Animated backdrop

A full-screen flag moves over a blue sky with slowly drifting clouds. Curtains.js deforms a textured mesh, with changing wind strength, wave spacing, flutter, and elastic movement at the two left-side attachment points. Wind episodes blend over approximately 10–26 seconds, with smaller gust changes between them.

A static image fallback is used if WebGL cannot initialize. The flag texture must still exist for that fallback to work.

### Photo and video panel

The upper-right quarter is a mixed-media slideshow. At the target resolution, its 50vw × 50vh area is **1920 × 1080 pixels**.

- Pictures remain visible for approximately **2 seconds**, excluding transition time.
- Videos play for their full duration, muted, without visible controls.
- Media uses `object-fit: contain`: the complete image stays visible without stretching or cropping.
- Unused margins remain transparent so the background can show through.
- The playlist is shuffled at the beginning of each pass; every usable item appears once per pass.
- When possible, the last item of one pass is not immediately repeated at the start of the next.
- Random SwiperGL shader transitions run at a configured speed of **1200 ms**.
- Normal images and videos render directly while at rest. WebGL uses snapshots only during transitions.
- Failed media is skipped. A video with no playback progress for 30 seconds is skipped as well.
- If transition initialization fails, the player falls back to showing the next media item directly.

### Information board

A large blue sign fills the lower-right area, with a solid readable face, rounded corners, a narrow translucent surround, and a CSS light divider. It intentionally extends beyond an exact quadrant: its configured size is **53vw × 52vh**.

| Area | Content |
| --- | --- |
| Upper left | Team banner artwork |
| Below the banner | Names for the current month |
| Upper right | Office directory with room numbers, titles, and people |
| Bottom left | Upcoming JBERLife events within the next four weeks |
| Bottom center | Events happening today, including descriptions |
| Bottom right | Air Force Times headlines and publication times |

Long lists scroll continuously. Lists that fit remain stationary. Events, news, and directory lists scroll at approximately **18 pixels per second**; monthly names scroll at **16 pixels per second**.

## How the project works

The system has two separate jobs:

1. **Prepare local content.** PowerShell exports Google Slides to PDF, converts slides to PNG images, imports phone media, downloads event/news/directory data, and generates the media playlist and monthly text files.
2. **Display local content.** `index.html` reads those files and periodically checks for changes. It runs from `file:///C:/www/index.html` in Edge kiosk mode.

The main display is one HTML page. Its components do not require separate iframe pages. JavaScript and CSS libraries are loaded from local files, rather than a CDN.

Checking a local file in the browser does **not** download fresh content from its original website. Run the corresponding PowerShell script or the full refresh process to update the local copy first.

## Requirements

| Component | Purpose |
| --- | --- |
| Windows kiosk computer | Runs the supplied PowerShell and Edge launch scripts |
| 3840 × 2160 landscape display | Matches the fixed portrait coordinates and overall composition |
| Microsoft Edge with hardware acceleration | Local playback, video decoding, and WebGL effects |
| PowerShell 7.2 or newer | Required by the current phone importer; PowerShell 7 is recommended for the full workflow |
| ImageMagick with `magick` available on PATH | Converts the downloaded leadership PDF into PNG images |
| Ghostscript | PDF decoding dependency for the ImageMagick conversion workflow |
| Git and Robocopy | Required when using `git-it.ps1` for repository updates |
| Network access to configured content sources | Required when refreshing external content |
| Android Platform Tools | Optional phone import; default ADB path is `C:\platform-tools\adb.exe` |
| Android phone with WhatsApp and authorized USB debugging | Optional media submission/import workflow |
| X-keys interface and MacroWorks | Physical button triggers using MacroWorks software mode |

A GPU capable of smooth 4K WebGL and video playback is appropriate. This folder does not establish a tested minimum GPU model or VRAM requirement. The project does not contain the local voice-cloning workload used by other DigitalSign configurations.

**Display setup matters:** use landscape orientation, native 4K output, and a Windows scaling setting that gives the page the intended 3840 × 2160 CSS-pixel viewport. The portrait positions are not automatically rearranged for smaller screens or portrait orientation.

## Installation

### 1. Copy the project to the deployment root

Copy the **contents** of `CPTS.Leadership` into `C:\www`, preserving the relative file structure. The page should be `C:\www\index.html`, not `C:\www\CPTS.Leadership\index.html`.

The scripts contain absolute `C:\www` paths. Moving the installation requires updating those paths as well as the launch commands.

### 2. Supply the local artwork and generated content

The checked-in project includes `images/Opatch.png` and `images/Mpatch.png`. Several other files are expected to be provided or generated at deployment:

| Path | How it is supplied |
| --- | --- |
| `assets/wonder.png` | Supply the flag texture; the page references this path, but it is not included in this project folder |
| `images/team.png` | Supply the team banner; it is referenced but not included in this project folder |
| `images/Leadership/slide-000.png` through `slide-007.png` | Generated from Google Slides |
| `images/Leadership/pdf/slides.pdf` | Downloaded by the conversion script |
| `pictures/` | Create for locally submitted pictures and videos |
| Local data files listed below | Generated by the refresh scripts |

Create the media folder before generating its playlist:

```powershell
New-Item -ItemType Directory -Path 'C:\www\pictures' -Force
```

### 3. Configure the source documents

Review these settings before the first refresh:

| Script | Setting |
| --- | --- |
| `DL-PDF2PNG.ps1` | `$presentations`: leadership Google Slides URL and output name |
| `Get-Directory.ps1` | `$CsvUrl`: directory spreadsheet CSV export |
| `teams.ps1` | `$CsvUrl`: monthly names spreadsheet CSV export |
| `Get-JBEREvents.ps1` | Event source and `$Weeks`, defaulting to 4 |
| `Get-AirForceTimesNews.ps1` | Air Force Times RSS feed URL |
| `Import-PhoneMedia.ps1` | ADB location, destination, and WhatsApp folder paths |

Google exports must be accessible to the account/process running the scripts. These scripts do not perform an interactive Google sign-in.

### 4. Prepare the phone, if used

Enable Developer options and USB debugging on the Android phone, connect its USB data cable, and accept the computer's debugging authorization on the phone.

```powershell
& 'C:\platform-tools\adb.exe' devices
```

The phone must appear with the state `device`, rather than `unauthorized` or `offline`. The importer selects a USB-connected device using `adb -d`; connect one intended phone for this workflow.

Configure WhatsApp media downloads on the phone before importing. If phone import is not part of this installation, remove or disable its invocation in `Refresh.ps1` after reviewing the desired workflow.

### 5. Generate local content

After configuring sources and reviewing the phone import behavior below:

```powershell
pwsh.exe -NoProfile -File 'C:\www\scripts\Refresh.ps1'
```

For setup and troubleshooting, individual scripts can also be run separately. Confirm that generated files exist before testing their display panels.

### 6. Launch the sign

```powershell
pwsh.exe -NoProfile -File 'C:\www\scripts\startupkiosk.ps1'
```

The supplied startup script launches Edge in full-screen kiosk mode and includes `--allow-file-access-from-files`. That flag is required by the local file-reading design. Opening the HTML by double-clicking it does not necessarily reproduce the configured kiosk environment.

The launch scripts expect Edge at:

```text
C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
```

Adjust that path if the deployment uses a different installation location.

## Editing the content

### Leadership portraits: Google Slides

Edit the presentation configured in `DL-PDF2PNG.ps1`. The downloader exports it as PDF and uses ImageMagick at **288 DPI** to produce the portrait images.

**Slide 1 is intentionally omitted.** Use it for instructions to content editors. Slide 2 becomes `slide-000.png`.

| Google Slides page | Generated file | Display position |
| --- | --- | --- |
| 1 | Omitted | Editor instructions only |
| 2 | `slide-000.png` | Top left |
| 3 | `slide-001.png` | Top center |
| 4 | `slide-002.png` | Top right of the leadership area |
| 5 | `slide-003.png` | Middle right |
| 6 | `slide-004.png` | Middle left |
| 7 | `slide-005.png` | Bottom left |
| 8 | `slide-006.png` | Bottom center |
| 9 | `slide-007.png` | Bottom right of the leadership area |

Provide at least nine presentation pages for all eight visible slots. Additional exported pages are not automatically assigned display positions. The middle-right/middle-left order above follows the actual HTML mapping.

Use a **4:5 portrait page ratio** to match the 528 × 660 display slots. The conversion removes alpha against white; exported portraits are opaque. Existing `slide-*.png` files are deleted before conversion attempts, so a failed conversion can leave those files unavailable until a successful rerun. Downloads and conversions have retry logic, including up to three outer retry cycles.

The browser checks the eight fixed filenames every five minutes and retains a displayed image if its replacement cannot be read or decoded. In this repository version it compares both SHA-256 file bytes and a SHA-256 fingerprint of native-resolution decoded pixels. Re-encoding an unchanged picture need not replace the visible image; actual pixel edits do.

### Monthly names: Google Sheets

`teams.ps1` reads the configured spreadsheet as CSV in memory and writes `A.txt` through `L.txt` beside `index.html`.

| Column / local file | Month | Column / local file | Month |
| --- | --- | --- | --- |
| A / `A.txt` | January | G / `G.txt` | July |
| B / `B.txt` | February | H / `H.txt` | August |
| C / `C.txt` | March | I / `I.txt` | September |
| D / `D.txt` | April | J / `J.txt` | October |
| E / `E.txt` | May | K / `K.txt` | November |
| F / `F.txt` | June | L / `L.txt` | December |

Row 1 is skipped. Each column starts at row 2 and stops at its first blank or whitespace-only cell, independently of other columns. Put one name in each cell and keep each month's list contiguous. An empty row 2 clears that month's output file.

The page selects the current month's file using the **computer's local date**, checks for a month change every minute, and reloads names every five minutes. These lists can represent birthdays, recognition, anniversaries, or another monthly category; the code simply displays names.

### Office directory: Google Sheets

The directory spreadsheet uses these headers:

| Header | Purpose |
| --- | --- |
| `Title` | Office, section, or role; required header |
| `Room` | Room identifier; required header |
| `Person 1` | Optional first person |
| `Person 2` | Optional second person |
| `Person 3` | Optional third person |

`Get-Directory.ps1` stops at the first blank `Title`. It trims text, collapses repeated whitespace, omits empty people fields, and writes `Directory.json`. The display shows the room, title, and people in spreadsheet order. Keep intentional entries above any blank title row.

### Pictures and videos

Place supported media directly in `C:\www\pictures`, or import it from the phone. Then run:

```powershell
pwsh.exe -NoProfile -File 'C:\www\scripts\Update-MediaPlaylist.ps1'
```

The playlist generator scans only files immediately inside `pictures`, not its subfolders. It ignores zero-byte files, checks whether files are readable, and retains the previous playlist if it encounters busy media. It writes only when the generated playlist changes.

| Kind | Playlist extensions |
| --- | --- |
| Images | `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.avif` |
| Videos | `.mp4`, `.webm`, `.m4v`, `.mov`, `.ogv` |

An accepted filename extension does not guarantee that Edge can decode its actual codec. MP4 with a browser-supported codec and JPEG/PNG images are practical choices for deployment.

The browser reads `media-playlist.json` every five minutes. A changed playlist is applied at the next media advance, allowing a current video to finish. Filenames include cache-busting values based on modification time and size so overwritten media can be refreshed.

#### WhatsApp phone import behavior

`Import-PhoneMedia.ps1` is a **one-time transfer**, not a watcher. It recursively scans these WhatsApp locations:

```text
/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video
/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images
/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents
```

**This is a move-and-cleanup workflow:**

- Supported media under a `/Private/` subfolder is deleted from the phone without being imported. Folder location alone determines this treatment.
- Other supported media is pulled into a temporary staging folder under `pictures`.
- The transferred size and phone size/modification timestamp are checked before processing continues.
- SHA-256 identifies exact duplicates against existing local media. Different encodings of the same-looking picture are not treated as identical.
- New files are moved into the destination; filename collisions receive a hash suffix or unique name.
- Successfully saved files and confirmed exact duplicates are removed from the phone after a further timestamp check.
- Per-file errors are logged; files are retained where the failure occurs before removal.

The scan is recursive and does not explicitly exclude `Sent` subfolders. Keep the intended contents of these folders in mind when choosing the phone's role.

The importer accepts more extensions than the slideshow playlist does. A HEIC, TIFF, DNG, MKV, or AVI file may be imported but not added to the playback list. Conversion to a supported playback format is a separate task. This version uses folder classification, metadata checks, and SHA-256; it does not require `ffprobe.exe`.

### Events and news

`Get-JBEREvents.ps1` downloads JBERLife events for **28 calendar days including today**, using Alaska time. It follows pagination, removes duplicates, strips HTML from text, sorts events, and writes both CSV and a human-readable text file.

The page reads the CSV for both event panels. Upcoming events are filtered to a rolling 28-day window. Today's panel includes events that start today and earlier-starting events whose end extends past today's midnight. Event selection uses `America/Anchorage`, even if the computer is set to another timezone.

`Get-AirForceTimesNews.ps1` downloads RSS headlines, deduplicates by link or title, sorts by publication time, and writes `AirForceTimes-News.json`. The display shows headlines and publication timestamps in Alaska time. It does not download full articles or article images.

Cached content remains viewable without a live connection, but it becomes stale until the scripts retrieve new data. A rolling event window cannot manufacture future events beyond the last downloaded dataset.

## Refresh and button operation

### Physical button integration

Use **MacroWorks in software mode** so the X-keys button can trigger scripts. The project includes `scripts/Script_1224_X.mw3` as a MacroWorks configuration file. Import and verify its button assignments on the target machine; do not assume the filename identifies the correct physical button.

A content-refresh button can invoke PowerShell 7 with:

```text
Program:   pwsh.exe
Arguments: -NoProfile -File "C:\www\scripts\Refresh.ps1"
```

Configure the button or an external launcher to run invisibly if desired. The PowerShell script itself does not supply that launch behavior.

### In-place content refresh

`Refresh.ps1` first writes `refresh-status.json`, then invokes these scripts sequentially:

1. `DL-PDF2PNG.ps1`
2. `Import-PhoneMedia.ps1`
3. `Get-JBEREvents.ps1`
4. `Get-AirForceTimesNews.ps1`
5. `Get-Directory.ps1`
6. `teams.ps1`
7. `Update-MediaPlaylist.ps1`

The running page checks refresh status every **2 seconds**. During the active status interval, the miniature clock is replaced by red text:

**Refreshing content please wait.**

A countdown begins at approximately `05:00`. At expiry, the normal clock returns automatically. A new refresh writes a new expiry time.

**The countdown is a fixed status interval, not a completion detector.** It does not measure progress, prove success, wait indefinitely for a long download, or end early when work finishes. Data panels independently detect updated local files on their own polling cycles.

`Refresh.ps1` does not restart Edge or rewrite `index.html`. It is also not a transactional update of all content: review console output if any component fails, because later steps are not a guarantee that earlier steps succeeded.

### Full browser recovery

`F5plus.ps1` provides the stronger refresh/recovery workflow:

1. Force-close Edge and open `loading.html` for visible button feedback.
2. Run `Refresh.ps1`.
3. Request a graceful Edge shutdown and wait ten seconds.
4. Force-close remaining Edge processes.
5. Clear the current account's Default-profile Edge session files.
6. Relaunch `index.html` in kiosk mode.

It affects **all `msedge` processes accessible to the script**, so use it on the dedicated kiosk account. `loading.html` is a local loading screen with animated Matrix-style rain. While that page is displayed, the main page's miniature refresh countdown is not visible.

### Scheduled operation

The scripts are one-shot operations. Configure Task Scheduler or existing automation for logon startup, periodic content retrieval, or playlist regeneration. No scheduled task or fixed nightly refresh time is automatically installed by these files.

Use PowerShell 7 for the complete refresh chain. `git-it.vbs` currently launches **Windows PowerShell** for repository synchronization only; it does not change the interpreter used by separately configured buttons or scheduled tasks.

## Script reference

| File | Purpose |
| --- | --- |
| `startupkiosk.ps1` | Launches the main local page in Edge kiosk mode |
| `Refresh.ps1` | Writes the five-minute status signal and runs the content preparation chain |
| `F5plus.ps1` | Shows loading feedback, refreshes content, and restarts Edge |
| `DL-PDF2PNG.ps1` | Downloads leadership Slides as PDF, skips page 1, converts remaining pages to PNG |
| `Import-PhoneMedia.ps1` | Imports/deduplicates WhatsApp media and removes processed phone files |
| `Update-MediaPlaylist.ps1` | Builds the local media playlist without opening or refreshing the browser |
| `Get-JBEREvents.ps1` | Downloads installation events to CSV and text |
| `Get-AirForceTimesNews.ps1` | Downloads headlines to JSON |
| `Get-Directory.ps1` | Converts directory spreadsheet CSV into local JSON |
| `teams.ps1` | Converts spreadsheet columns A–L into monthly text files |
| `git-it.ps1` | Clones the repository to a temporary folder and overwrites matching deployment files |
| `git-it.vbs` | Hidden launcher for `git-it.ps1` |
| `Reboot.ps1` | Immediately requests a Windows restart using `shutdown -r -t 00` |
| `Script_1224_X.mw3` | MacroWorks configuration supplied with the project |

### Repository synchronization

`git-it.ps1` clones the `main` branch of DigitalSign and copies the contents of `CPTS.Leadership` into `C:\www` using Robocopy.

It forcefully replaces matching files, including unchanged-looking matches, while leaving destination-only files and folders in place. It does **not** use `/MIR` or purge `C:\www`. Its temporary clone is removed after copying.

Local edits to files that also exist in the repository can be overwritten. Generated content and local artwork absent from the repository remain in place, but a future repository file with the same path would become a matching file. The update script does not itself run content refresh or restart the browser.

## Local files and update intervals

### Deployment file map

| Path relative to `C:\www` | Role |
| --- | --- |
| `index.html` | Main layout, styling, media player, local data readers, clock, and effects |
| `setup.js` | Flag mesh, shaders, wind behavior, and WebGL fallback |
| `curtains.umd.js` | Local Curtains.js dependency |
| `swiper-11-bundle.min.js` / `.css` | Local Swiper 11 dependency |
| `swiper-gl.min.js` / `.css` | Local SwiperGL transitions |
| `loading.html` | Recovery/loading page |
| `index.html.old` | Older copy; not the active kiosk entry point |
| `images/Opatch.png`, `images/Mpatch.png` | Logo and patch artwork |
| `images/team.png` | Deployment-supplied banner |
| `assets/wonder.png` | Deployment-supplied flag texture |
| `images/Leadership/` | Generated portrait PNGs and the PDF subfolder |
| `pictures/` | Imported or manually supplied slideshow media |
| `pictures/.phone-import/` | Temporary importer staging area |
| `media-playlist.json` | Generated media item list |
| `Directory.json` | Generated office directory |
| `AirForceTimes-News.json` | Generated headline cache |
| `JBER-Events.csv` | Event dataset consumed by the display |
| `JBER-Events.txt` | Human-readable event export |
| `A.txt` through `L.txt` | Monthly name lists |
| `refresh-status.json` | Refresh start and expiry timestamps |
| `scripts/` | PowerShell, launcher, and MacroWorks files |

### Browser checks

| Component | Interval / trigger |
| --- | --- |
| Clock | Every second |
| Refresh countdown status file | Every 2 seconds |
| Leadership image contents | At startup, then every 5 minutes |
| Media playlist | At startup, then every 5 minutes |
| Event CSV | At startup, then every 5 minutes per event panel |
| Event date filtering | Every minute |
| News and directory files | At startup, then every 5 minutes |
| Monthly names | At startup, every 5 minutes, and on return to visible state |
| Month selection | Every minute |

These are browser read intervals, not automatic network download schedules. Several JSON writers use temporary files and replacement to reduce partial reads. This protection is not universal: the event exports and monthly text outputs use direct writes, and leadership conversion replaces PNGs in place.

## Customization

### Change the organization

Replace the Google source URLs, `Opatch.png`, `Mpatch.png`, and `team.png`. Edit the directory heading and other labels in `index.html`. Preserve expected output names or update the matching HTML readers when changing them.

### Change layout or resolution

Edit the inline CSS in `index.html`. The leadership area uses absolute pixel coordinates; the slideshow and information board mix viewport dimensions with fixed artwork positions. Changing the display size is therefore a layout adjustment, not just a browser zoom setting.

The default portrait coordinates are:

| Class | Left | Top | Width × height |
| --- | --- | --- | --- |
| `.img-L1` | 37 px | 52 px | 528 × 660 px |
| `.img-L2` | 649 px | 52 px | 528 × 660 px |
| `.img-L3` | 1261 px | 52 px | 528 × 660 px |
| `.img-L4` | 37 px | 750 px | 528 × 660 px |
| `.img-L5` | 1261 px | 750 px | 528 × 660 px |
| `.img-L6` | 37 px | 1448 px | 528 × 660 px |
| `.img-L7` | 649 px | 1448 px | 528 × 660 px |
| `.img-L8` | 1261 px | 1448 px | 528 × 660 px |

### Change timing and motion

- Change the image timer's `2000` value in the media player's `schedule()` function to alter picture dwell time.
- Change the Swiper `speed: 1200` setting for transition speed.
- Change each panel's `SCROLL_PIXELS_PER_SECOND` value for scrolling speed.
- Change monthly names' `distance / 16` calculation for their scroll rate.
- Change five-minute polling intervals in the corresponding readers when needed.
- Adjust wind pattern ranges and `ROPE_GIVE` in `setup.js` for flag motion.

Changing `Get-JBEREvents.ps1 -Weeks` alone does not change the browser's 28-day upcoming filter or its “NEXT 4 WEEKS” heading. Update the downloader, display filter, and label together if extending the visible window.

## Maintenance and troubleshooting

| Symptom | Check or action |
| --- | --- |
| Flag is missing | Supply `C:\www\assets\wonder.png`; confirm filename and path before investigating WebGL |
| Team banner is missing | Supply `C:\www\images\team.png` |
| Portrait slots are blank | Run `DL-PDF2PNG.ps1`; check Slides export access, ImageMagick/Ghostscript, and that the deck has page 1 plus eight portrait pages |
| Portraits appear in the wrong middle slots | Follow the explicit slide mapping: `slide-003` is middle right, `slide-004` is middle left |
| Local panels remain on waiting messages | Confirm generated files exist and Edge was launched with `--allow-file-access-from-files` |
| Media folder has files but nothing plays | Run `Update-MediaPlaylist.ps1`; files must be directly inside `pictures`, have accepted extensions, and use decodable formats |
| Newly copied media is not yet shown | Regenerate the playlist, allow the five-minute browser check, then allow the current item to finish |
| Phone is not found | Check USB data cable, USB debugging authorization, `adb devices`, and that only the intended USB device is selected |
| Phone files disappear after import | This is the documented move-and-cleanup behavior; Private-folder media is discarded and successful/duplicate imports are removed |
| Names after a blank spreadsheet cell do not appear | Each month stops at its first blank cell; remove gaps |
| Directory stops partway down the sheet | Check for a blank `Title` row |
| Clock differs from event dates | Clock/monthly selection use computer local time; event selection and news timestamps use Alaska time |
| Refresh message ends while downloads continue | Countdown is fixed at five minutes and does not track completion |
| Google edits do not show up | Run the download scripts first; browser polling reads local files only |
| Content is stale after internet loss | Cached files remain local; restore access and run the appropriate downloader |
| Effects stutter | Check Edge hardware acceleration, GPU drivers, native resolution, video formats, and other GPU workloads |
| Browser has a banner or loses focus | Use the dedicated kiosk recovery workflow in `F5plus.ps1` |
| Repository update removes a local customization | Matching tracked files are overwritten; retain intentional changes in the repository or keep a separate backup |

Run individual scripts interactively to see errors. Browser developer tools provide warnings for failed media, unreadable data, image replacement failures, and unavailable WebGL transitions.

Useful focused checks:

```powershell
# Verify required commands are discoverable.
Get-Command pwsh, magick, git

# Verify phone authorization.
& 'C:\platform-tools\adb.exe' devices

# Refresh a single content source.
pwsh.exe -NoProfile -File 'C:\www\scripts\Get-Directory.ps1'

# Rebuild the media list after local changes.
pwsh.exe -NoProfile -File 'C:\www\scripts\Update-MediaPlaylist.ps1'
```

## Credits and dependencies

The display combines project-specific HTML, CSS, JavaScript, and PowerShell with **Curtains.js**, **Swiper 11**, and **SwiperGL**. Keep their local dependency files and applicable license notices when redistributing the project. This folder includes `curtains.LICENSE.txt` and `SWIPER-LICENSE.txt`; review applicable terms for all bundled dependencies rather than assuming those two files license every component.

Content comes from the configured Google Slides/Sheets documents, submitted media, JBERLife, and Air Force Times. Logos, photographs, flag artwork, and banner artwork retain their respective ownership and usage requirements.

---

<details>
<summary>🥚 A small seasonal secret</summary>

### Winter arrives on its own

There is a seasonal snowfall effect hidden in the main page. It activates during **December, January, and February**, using the computer's local date. Outside those months, falling layers and accumulated caps are hidden, and the active snowfall animation stops. Season checks run every minute and when the page becomes visible again.

### Twenty-one layers of depth

The snowfall uses **21 transparent canvas layers**, distributed across the existing integer stacking levels **0 through 7**. Several depth layers share a z-index so the effect fits around the flag, portraits, signs, and logos without moving the page's content into a new stacking scheme.

Distant flakes are smaller, slower, and fainter. Nearer flakes are larger, faster, and more opaque. Each layer has its own phase, sway frequency, and wind contribution. Nominal radius progresses from **0.7 to 5.6 pixels**, with additional per-flake variation.

At full intensity, the configured baseline is **55 flakes per layer**, scaled by screen area and capped at twice the baseline. At a 3840 × 2160 viewport, that creates 110 flake slots per layer, or **2,310 across all 21 layers**. Falling-layer canvases render at half resolution (`renderScale: 0.5`) to reduce rendering cost.

### Changing weather

The effect begins at full density when winter activates. Every **three hours of active page operation**, it selects a target density from **20%, 40%, 60%, 80%, or 100%**. It approaches the target smoothly at a rate of one full intensity unit per minute; the actual transition duration depends on the size of the change.

Reloading the page restarts this intensity schedule. It is independent of the flag's wind simulation.

### Snow collects on visible image edges

Elements marked with `data-snow` can collect snow. The supplied targets are the eight leadership images and the two logo/patch images. Other panels and slideshow content do not automatically become accumulation surfaces.

The script reads each image's alpha pixels to locate the first eligible visible pixel in each column. Its alpha threshold is **32 out of 255**, approximately **12.5% opacity**. Fully transparent columns and pixels below that threshold are ignored. Thus, an image pixel at about 10% opacity does not support accumulation under the default setting.

Flakes deposit only on targets assigned to their matching stacking layer. Each qualifying collision has a configured **72% deposition chance**. Deposits follow the sampled top outline and avoid bridging fully transparent gaps between disconnected image sections. This is a column-based outline simulation, rather than a complete physical model of every interior image surface.

### A different accumulation limit each day

The baseline accumulation depth is **25 pixels**. A deterministic calculation based on the local date chooses a multiplier from **1 through 5**, giving a daily maximum of **25, 50, 75, 100, or 125 pixels**.

The day's limit stays consistent across reloads because it is date-seeded. The accumulated snow itself is held in memory and is **not saved** across reloads. When the daily limit decreases, existing depth is clamped to the new maximum. Rebuilding image targets can also reset their caps.

### Tuning the secret

Search the snowfall section of `index.html` for these values:

| Setting | Default | Effect |
| --- | --- | --- |
| `WINTER_MONTHS` | `[11, 0, 1]` | Active months, using JavaScript's zero-based month numbers |
| `CONFIG.layers` | `21` | Number of depth layers |
| `CONFIG.flakesPerLayer` | `55` | Baseline flake allocation before screen-area scaling |
| `CONFIG.minRadius` / `maxRadius` | `0.7` / `5.6` | Depth-based flake size range |
| `CONFIG.depositChance` | `0.72` | Probability of deposition at a qualifying collision |
| `BASE_ACCUMULATION_DEPTH` | `25` | Base depth used by the daily multiplier |
| `CONFIG.renderScale` | `0.5` | Falling canvas rendering resolution |
| `CONFIG.alphaThreshold` | `32` | Minimum image alpha that supports accumulation |
| `SNOW_INTENSITIES` | `[.2, .4, .6, .8, 1]` | Possible density targets |
| `INTENSITY_INTERVAL_MS` | `3 * 60 * 60 * 1000` | Delay between density selections |

`CONFIG.maxDepth` is recalculated from `BASE_ACCUMULATION_DEPTH`, so change the base constant when adjusting the daily accumulation range.

Developer-console controls are available:

```javascript
Snowfall.pause();       // Pause movement and deposition.
Snowfall.pause(false);  // Resume during the active season.
Snowfall.clear();       // Clear accumulated caps.
Snowfall.refresh();     // Rebuild targets after changing eligible elements.
```

Pausing does not hide already drawn flakes or accumulated caps. Clearing changes cap data; visible clearing is applied by the next active drawing frame. `refresh()` rebuilds eligible targets and resets their accumulated depth. These controls do not override the seasonal date check.

To add a target, give it `data-snow` and an explicit supported z-index. Image pixels must be readable by canvas for alpha-aware accumulation; an unreadable image logs a warning and does not gain a rectangular fallback cap.

</details>
