# CPTS Leadership — Scripts

A press of an X-keys button brings new leadership slides, phone-submitted photos and videos, office directory entries, birthdays, events, and headlines onto the digital sign. These PowerShell scripts collect and prepare that content as local files for Microsoft Edge to display.

The three operator actions each have **their own X-keys button**: refresh content, refresh content and restart the browser, or reboot the computer. MacroWorks runs in **software mode** and launches the assigned script with its console hidden.

This folder supports the [CPTS Leadership display](../). Deploy its contents to `C:\www\scripts` alongside the rest of the project in `C:\www`. Playback uses local files without a web server; downloading updates requires access to the relevant online sources.

## The three X-keys buttons

The included `Script_1224_X.mw3` maps the XK-3 Switch Interface as follows:

| Button | Script | Action |
| --- | --- | --- |
| SW1 / 1001 | `Refresh.ps1` | Updates content while the current kiosk page remains open. |
| SW2 / 1002 | `F5plus.ps1` | Shows a loading page, runs the content refresh, then closes and relaunches Edge on the main display. |
| SW3 / 1003 | `Reboot.ps1` | Immediately restarts Windows. |

Each mapping responds to the initial button press. The MacroWorks helper starts PowerShell hidden and waits for it to finish. MacroWorks must be running in the signed-in kiosk session for these software-mode actions to work.

**PowerShell setup:** the included MacroWorks file currently launches `powershell.exe`, which is Windows PowerShell. `Import-PhoneMedia.ps1` requires **PowerShell 7.2 or later**. Before using the full refresh workflow, change the helper's `psi.FileName` to your installed `pwsh.exe` path, for example `C:\Program Files\PowerShell\7\pwsh.exe`. Installing PowerShell 7 alone does not change the executable used by this mapping.

### Refresh.ps1 — update content

This is the central content refresh sequence. It first writes `C:\www\refresh-status.json` with UTC start and expiration timestamps five minutes apart. The display reads that file to replace its clock with red **“Refreshing content please wait.”** text and a countdown.

It then calls these scripts in order:

1. `DL-PDF2PNG.ps1` — download and convert leadership slides.
2. `Import-PhoneMedia.ps1` — import WhatsApp media over USB.
3. `Get-JBEREvents.ps1` — retrieve installation events.
4. `Get-AirForceTimesNews.ps1` — retrieve news headlines.
5. `Get-Directory.ps1` — retrieve office directory entries.
6. `teams.ps1` — export the monthly name lists.
7. `Update-MediaPlaylist.ps1` — rebuild the photo/video playlist after import.

The countdown is a fixed five-minute display window, **not a measurement of script progress**. It expires automatically and returns to the clock; it does not end early when downloads finish or extend when a refresh takes longer. The current page checks the status file every two seconds.

`Refresh.ps1` does not restart Edge, reboot Windows, or rewrite `index.html`. The page's existing content checks determine when refreshed files appear. The sequence does not provide a combined success report or rollback, so diagnose a missing content source by running its individual script visibly.

### F5plus.ps1 — refresh and recover the browser

Use this button when the sign needs fresh content and a clean browser launch, such as after a display problem or an obstructing browser window.

1. Force-closes running Edge processes.
2. Opens `C:\www\loading.html` in fullscreen kiosk mode for immediate button feedback.
3. Calls `Refresh.ps1` and waits for it to return.
4. Requests a graceful Edge close and waits ten seconds.
5. Force-closes any remaining Edge processes.
6. Removes files in the current user's Edge `Default\Sessions` folder.
7. Relaunches Edge on `C:\www\index.html` in fullscreen kiosk mode.

The ten-second pause occurs **after the refresh sequence**, during browser shutdown. The script targets all `msedge` processes, so use it on the dedicated sign computer. Its Edge executable path is `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`.

### Reboot.ps1 — restart the computer

Runs `shutdown -r -t 00`: Windows restarts immediately. This button does not download content first. Automatic sign-in and the startup launch must be configured separately if the display should return unattended after reboot.

## Content preparation scripts

### DL-PDF2PNG.ps1 — Google Slides to local PNGs

Downloads each presentation configured in `$presentations` as a PDF, then uses ImageMagick to render its pages at density 288. The current configuration contains one presentation named `Leadership`.

| Output | Default location |
| --- | --- |
| Downloaded presentation | `C:\www\images\Leadership\pdf\slides.pdf` |
| Rendered slides | `C:\www\images\Leadership\slide-000.png`, `slide-001.png`, and so on |

**The first PDF page is discarded.** Keep instructions on slide 1; Google Slides page 2 becomes `slide-000.png`. Output is flattened onto white with alpha removed.

Downloads run sequentially and conversion is dispatched to background jobs. The script waits for those jobs before returning. It supports three download attempts, three conversion attempts, and up to three outer cycles for failed presentations, with ten-second retry delays.

Existing `slide-*.png` files in the presentation folder are removed before each conversion attempt. A failed conversion can therefore leave that folder without its previous images. Change the presentation URLs and names in `$presentations`; names determine the output folders and must match the display's configuration.

### Import-PhoneMedia.ps1 — WhatsApp USB media import

Runs one import pass from an authorized USB-connected Android phone. Defaults:

| Setting | Value |
| --- | --- |
| ADB executable | `C:\platform-tools\adb.exe` |
| Destination | `C:\www\pictures` |
| Temporary staging | `C:\www\pictures\.phone-import` |

It recursively scans these WhatsApp media folders:

- `/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video`
- `/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images`
- `/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents`

For supported files outside `Private` subfolders, the script pulls to temporary storage, compares the transferred size with the phone's size, checks that the phone file's size and modification time stayed unchanged, and computes a local SHA-256 hash. Identical content already present locally is treated as a duplicate; otherwise it is moved into the destination. Filename collisions receive a hash suffix or unique name.

After saving a new file or identifying an existing exact local duplicate, the phone copy is removed, subject to another phone metadata check. This is a **move workflow**, so imported media is intentionally removed from the phone.

**Supported media inside `/Private/` is deleted directly from the phone without importing it.** Folder location is the rule; the script does not compare its resolution, quality, or duration against another copy. Review that behavior before adapting it to another phone workflow.

The current version uses ADB and local hashing; it does not invoke ffprobe. It imports some formats that the playlist does not include, such as HEIC and MKV. Importing a file does not guarantee that Edge can play it.

### Get-JBEREvents.ps1 — installation events

Downloads JBERLife events for four weeks by default, including today, using Alaska time. It follows feed pagination, removes duplicate events, cleans HTML from text, and sorts entries by start time and title.

Writes `C:\www\JBER-Events.csv` for the display and `C:\www\JBER-Events.txt` for a readable listing. Fields include dates, all-day status, title, location, address, timezone, cost, description, and URL. The download completes before output replacement begins.

Use `-Weeks` to request 1–52 weeks or `-OutputFolder` to change the destination.

### Get-AirForceTimesNews.ps1 — headlines

Downloads the Air Force Times RSS feed, removes duplicate entries, and sorts headlines newest first. Writes `C:\www\AirForceTimes-News.json` containing the source, update timestamp, and each headline's title, publication timestamp, and URL.

An empty feed is treated as an error so the existing news file is retained. Successful output uses a temporary file followed by replacement.

### Get-Directory.ps1 — office directory

Downloads the configured Google Sheet as CSV and writes `C:\www\Directory.json`.

The sheet must contain `Title` and `Room` headers. Optional people columns are `Person 1`, `Person 2`, and `Person 3`. Processing stops at the first blank `Title`. Text whitespace is normalized, and blank people entries are omitted. Missing required headers cause an error while preserving the existing directory file.

Change `$CsvUrl` to use another sheet with the same column structure.

### teams.ps1 — monthly name lists

Downloads its configured Google Sheet into memory, skips header row 1, and processes columns A through L independently, starting at row 2. Each column stops at its first blank or whitespace-only cell.

Writes `C:\www\A.txt` through `C:\www\L.txt`, one value per line, as UTF-8 without a byte-order mark. An empty row 2 clears that column's output file. The display uses these files for birthday names: A is January, B is February, continuing through L for December.

Despite its filename, this script reads Google Sheets; it does not connect to Microsoft Teams.

### Update-MediaPlaylist.ps1 — local media inventory

Scans files directly inside `C:\www\pictures` and writes `C:\www\media-playlist.json`. Subfolders are excluded.

| Type | Included extensions |
| --- | --- |
| Images | `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.bmp`, `.avif` |
| Videos | `.mp4`, `.webm`, `.m4v`, `.mov`, `.ogv` |

Zero-byte files are skipped. Each entry includes its media kind and a URL with a version value based on file modification time and size. Unchanged playlist content is left untouched. If a media file cannot be opened for reading, the script stops and preserves the existing playlist for a later retry.

This script runs once and exits. It does not open Edge or install a schedule. It is called at the end of `Refresh.ps1`; any additional five-minute execution must be configured separately. The current display also checks the saved playlist every five minutes. Playlist creation and page checking are separate actions.

## Deployment and support scripts

| File | Purpose |
| --- | --- |
| `startupkiosk.ps1` | Launches Edge on `C:\www\index.html` with fullscreen kiosk and local-file access arguments. It does not install an at-logon task or monitor Edge. |
| `git-it.ps1` | Clones the repository's `main` branch to `%TEMP%\DigitalSign-Download`, copies the contents of `CPTS.Leadership` into `C:\www`, and removes the temporary clone. |
| `DoThis.ps1` | Prints `Doing it!`. It is currently a placeholder called after `git-it.ps1` finishes. |
| `Script_1224_X.mw3` | MacroWorks software-mode configuration for the three independent X-keys buttons. |

`git-it.ps1` uses Robocopy `/E /IS /IT` to replace matching files, including files that otherwise appear unchanged. Destination files absent from the repository are left in place; it does not purge `C:\www`. Repository updates can overwrite local script customizations. The downloader does not itself refresh content or restart Edge; its current follow-up is the placeholder `DoThis.ps1`.

## Setup

1. Place the full CPTS Leadership project in `C:\www`, with this folder's scripts in `C:\www\scripts`. Keep `index.html` and `loading.html` at the project root.
2. Install PowerShell 7.2 or later. Use `pwsh.exe` for the complete refresh workflow.
3. Install ImageMagick with `magick` available on PATH and Ghostscript for PDF rendering. Confirm PDF conversion works under the kiosk account.
4. Install Git if using `git-it.ps1`.
5. Place Android Platform Tools at `C:\platform-tools`, enable USB debugging on the phone, and authorize the kiosk computer. Configure WhatsApp to download incoming media to the monitored folders.
6. Review the presentation and spreadsheet URLs in the content scripts. The downloads must be accessible to the scripts without an interactive sign-in.
7. Load the MacroWorks configuration for the XK-3 Switch Interface in software mode, update its PowerShell executable to PowerShell 7, and verify all three button assignments.
8. Configure `startupkiosk.ps1` to run at kiosk sign-in using your existing startup or Task Scheduler setup. Configure unattended sign-in separately if required.

The account running the scripts needs write access to `C:\www`, access to the phone through ADB, and permission to perform the selected Windows actions. Browser launch and recovery should run in the interactive kiosk user's session.

## Run individual tasks manually

Run these from PowerShell 7 to see diagnostic output:

```powershell
# Full content update, without restarting Edge
& 'C:\www\scripts\Refresh.ps1'

# USB phone authorization check
& 'C:\platform-tools\adb.exe' devices

# Rebuild the local photo/video inventory
& 'C:\www\scripts\Update-MediaPlaylist.ps1'

# Download a different event window
& 'C:\www\scripts\Get-JBEREvents.ps1' -Weeks 6
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Button press does nothing | MacroWorks is running in software mode, the correct device configuration is loaded, and the assigned script exists. Run the script visibly to expose errors hidden by the button launcher. |
| Refresh runs but phone import fails | MacroWorks must launch PowerShell 7.2 or later. Check ADB's device list for an authorized USB device. |
| Slides are missing or conversion fails | Check presentation access, `magick` on PATH, Ghostscript, and PDF rendering policy. Remember slide 1 is discarded and old PNGs are removed before conversion attempts. |
| Countdown ends before updates finish | The timer is a fixed five-minute window, not a completion signal. |
| New media exists but is absent from the slideshow | Rebuild the playlist after copying or importing, allow time for the page's next check, and confirm the extension and codec are supported. |
| Events, directory, or news are stale | Run the corresponding downloader visibly and check network access, source format, and output timestamps. |
| Edge does not return after reboot | Verify automatic sign-in and the startup task; `Reboot.ps1` only requests the restart. |
| Git updates appear to do nothing to the screen | `git-it.ps1` updates disk files. Its current follow-up does not refresh content or relaunch the browser. |

These scripts prepare files and perform operator actions. Scheduling, automatic sign-in, and ongoing process monitoring are configured outside this folder.
