# Portrait Open/Closed Digital Signage and Cloned Voice Announcements 

A Windows kiosk display with separate **open** and **closed** layouts, remotely editable Google Slides content, and locally generated voice announcements controlled through Google Sheets.

The display is built around a **4K portrait screen (2160 × 3840)**. Two Google Slides presentations are stacked vertically beneath a fixed PNG overlay. Staff can change the displayed information, announcement text, playback setting, and selected voice without editing the kiosk's code.

## What appears on the screen

| Mode | Displayed content | Overlay | Audio |
| --- | --- | --- | --- |
| Open | Two published Google Slides presentations in `open.html` | `New-FMF-Template.png` | No announcement player in this page |
| Closed | Two separate published Google Slides presentations in generated `closed.html` | `New-FMF-Template-I.png` | Optional repeating announcement from `message.wav` |

Both modes start their presentations automatically and loop them, with a configured slide delay of **60 seconds**. Each presentation frame is 2144 pixels wide and 1939 pixels high. The PNG overlay sits above both frames to provide the surrounding design.

The layout uses fixed pixel positions for the portrait kiosk; it is not a responsive desktop or phone layout.

## Updating the visual content

Edit the Google Slides presentations already connected to the desired mode. Text, images, colors, slide order, and the number of slides can be changed in Google Slides without rebuilding the HTML or copying images to the computer.

1. Open the presentation for the appropriate mode and screen section.
2. Edit, add, remove, or reorder slides.
3. Ensure the presentation remains published to the web and that published changes are available.
4. Reload the kiosk page when needed to load the updated presentation.

Google's publishing and caching can affect when edits appear. The `delayms=60000` setting controls slide advancement; it is not a guarantee that published edits refresh every minute.

To use different presentations, replace the two embed URLs in:

- **Open mode:** [`open.html`](open.html).
- **Closed mode:** the HTML template inside [`QwenVoice/Update-Announcement.ps1`](QwenVoice/Update-Announcement.ps1).

Changes made directly to generated `closed.html` are replaced the next time the announcement updater runs. To change the slide interval, edit `delayms` in the relevant URLs; the value is in milliseconds.

## Controlling the announcement with Google Sheets

The spreadsheet URL is configured in [`QwenVoice/deployment.json`](QwenVoice/deployment.json). Its selected tab must be readable through Google's CSV export without signing in.

| Cell or range | Purpose |
| --- | --- |
| `A2` | Text for the generated announcement; must not be empty |
| `B2` | Playback switch: `Yes` / `No` or `On` / `Off` |
| `B4` | Name of the selected voice |
| `A10` downward | HTTPS download links to voice ZIP files |
| `B10` downward | Voice names corresponding to the ZIP links in column A |

The name in `B4` must match exactly one name in the voice list; matching ignores letter case. Avoid duplicate voice names.

**Turning playback off does not skip speech generation.** The updater still creates a new `message.wav`, but builds `closed.html` without an audio player. With playback enabled, the page contains an invisible player that automatically repeats the announcement.

Spreadsheet edits take effect when the updater runs, followed by a page reload. They do not directly change a page already running in Edge.

### Adding or selecting a voice

Each voice ZIP must contain exactly two files:

- `reference.txt` — the transcript of the reference recording.
- Either `reference.wav` **or** `reference.mp3` — the reference recording.

The transcript must be nonempty and the recording must be at least three seconds long. Google Drive links are supported when the ZIP is accessible without signing in and downloads are allowed.

Add the ZIP link and its voice name to the same row in columns A and B, starting at row 10. Put that name in `B4`, then run the updater.

Downloaded voices are validated and stored in:

```text
C:\www\QwenVoice\Voice\<voice name>
```

A valid cached voice is reused without downloading it again. This lets an existing kiosk continue using that voice even if its original ZIP is later removed from Drive. Keep the matching voice-list entry in the spreadsheet. A new kiosk still needs the ZIP or a copy of the cached voice.

Changing a ZIP at the same link does not replace an already valid cached voice. Use a new voice name to download and select a revised sample separately.

## How an announcement update works

Run:

```text
C:\www\QwenVoice\Update-Announcement.cmd
```

The launcher prefers PowerShell 7 when available and falls back to Windows PowerShell. The updater:

1. Reads the message, playback switch, and selected voice from Google Sheets.
2. Reuses the cached voice or downloads and validates its ZIP.
3. Updates the voice references in `settings.json` and writes the message to `script.txt`.
4. Runs the local Qwen speech generator.
5. Builds the closed-display HTML with or without its audio player.
6. Publishes `C:\www\message.wav` and `C:\www\closed.html`.

The updater prevents overlapping updater runs and stages output before replacing the published files. Input or generation failures leave the previous published output in place. The WAV and HTML are replaced individually, not as one combined transaction.

Daily updater logs are written to `C:\www\QwenVoice\logs`. Do not run manual generation at the same time as the updater because they share settings and input files.

## Kiosk buttons

The included MacroWorks 3 configuration targets an **X-keys XK-3 Switch Interface, PID 1224**.

| Switch | Action | Script |
| --- | --- | --- |
| 1 | Immediately restart Windows | `scripts/Reboot.ps1` |
| 2 | Close Edge and launch the open display | `scripts/open-button.ps1` |
| 3 | Run the announcement updater and launch the closed display | `scripts/closed-button.ps1` |

The MacroWorks configuration launches PowerShell hidden. The open and closed scripts close Edge windows, terminate remaining Edge processes, clear the default profile's session restore files, and relaunch Edge in full-screen kiosk mode. These actions affect all Edge windows for that user, so the scripts are intended for a dedicated kiosk account.

## Installing on a new kiosk

### Requirements

- Windows with Microsoft Edge and PowerShell.
- Git for the repository update script.
- 64-bit Python 3.11 with the Python launcher for the default voice setup.
- A compatible NVIDIA GPU and driver; setup checks CUDA availability.
- Internet access for initial setup, Google Slides, spreadsheet retrieval, and uncached voice downloads.
- Audio output for announcements.
- MacroWorks 3 and the supported X-keys interface if using physical buttons.

### Setup

1. Copy the **contents** of `CPTS.FMF` into `C:\www`, preserving its subfolders.
2. Set the display to 2160 × 3840 portrait and verify Windows scaling against the fixed-pixel layout.
3. Run `C:\www\QwenVoice\Setup.cmd`. Setup creates `.venv`, installs dependencies, downloads models, and checks the GPU.
4. Confirm the spreadsheet URL in `QwenVoice\deployment.json`. The default `web_folder` value of `..` places output in `C:\www`.
5. Configure the spreadsheet and voice ZIP, then run `Update-Announcement.cmd` to create the initial closed page and audio.
6. Test both display modes and audible autoplay under the actual kiosk account. Edge policy must permit the intended autoplay behavior.
7. Configure buttons, logon startup, and scheduled updates as needed. These are not installed automatically by voice setup.

**Startup path to check:** the included `scripts/startupkiosk.ps1` currently calls `C:\QwenVoice\Update-Announcement.ps1`, while the packaged deployment and closed-button script use `C:\www\QwenVoice\Update-Announcement.ps1`. Adjust the startup script to the deployed location before using it on a new kiosk.

The launch scripts also assume Edge is installed at `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`. Update that path if the installation differs. Run visible kiosk startup in the signed-in kiosk user's session.

## Updating the installed project

[`scripts/git-it.ps1`](scripts/git-it.ps1) downloads the `main` branch of this repository into a temporary folder, then uses Robocopy to copy the contents of `CPTS.FMF` into `C:\www`.

It copies subfolders and leaves destination-only files and folders in place. This preserves local models, the Python environment, cached voices, logs, and generated output. It does not mirror-delete the destination. Robocopy uses its normal file comparison rules; the current command does not force every identical file to be recopied.

Keep `.venv`, `models`, `cache`, and `Voice` on the kiosk. Routine source updates do not require rebuilding a working Python environment. Permanent configuration changes should also be made in the repository because subsequent copies can replace the tracked JSON configuration files.

A schedule must be configured separately; the download script itself does not create a nightly task or refresh an already open display.

## Main files

| File or folder | Role |
| --- | --- |
| `open.html` | Open-mode page with two Google Slides embeds |
| `New-FMF-Template.png` | Open-mode overlay |
| `New-FMF-Template-I.png` | Closed-mode overlay |
| `QwenVoice/Update-Announcement.ps1` | Spreadsheet processing, voice generation, and closed-page template |
| `QwenVoice/deployment.json` | Spreadsheet URL and web output folder |
| `QwenVoice/settings.json` | Model, language, chunking, pauses, trimming, and loudness settings |
| `QwenVoice/voice-cache.py` | Spreadsheet reading and voice download/cache validation |
| `QwenVoice/generate.py` | Local speech generation |
| `QwenVoice/qwen_volume.py` | Audio loudness processing |
| `QwenVoice/Setup.cmd` and `Setup.ps1` | Python environment and model setup |
| `scripts/` | Kiosk launch, button, reboot, and repository update scripts |
| `closed.html` and `message.wav` | Generated locally; not supplied as source files in this folder |

The supplied voice configuration uses the **0.6B model**, English, seed 42, 300-character chunks, 0.22-second pauses, 0.22-second startup trimming, a 5 ms fade-in, -16 LUFS loudness, and a -1.5 dBFS peak ceiling. See [`QwenVoice/README.md`](QwenVoice/README.md) for the voice subsystem's deployment notes.

## Connectivity and troubleshooting

Speech synthesis runs locally after setup. The full sign still needs internet access: Google Slides are embedded live, each announcement update reads Google Sheets, and uncached voices must be downloaded. No local web server or PowerPoint installation is required.

| Symptom | What to check |
| --- | --- |
| Slides are blank or stale | Internet connectivity, published presentation access, the correct embed URLs, and page reload |
| Announcement is silent | `B2`, successful generation, Windows audio output, Edge autoplay policy, and reloading the closed page |
| Selected voice fails | `B4` matches one list entry, ZIP access, required filenames, and the updater log |
| A changed voice ZIP is ignored | A valid cached voice is being reused; select a new voice name for a new download |
| Closed page is missing | Run `Update-Announcement.cmd` successfully before launching it |
| Startup cannot find the updater | Correct the startup path noted above |
| Overlay or content is misaligned | Portrait resolution, Windows scaling, overlay dimensions, and fixed iframe positions |

The included `open.html` also contains a duplicated `<iframe` token in the first embed's opening tag. Browsers may recover from it, but it should be reduced to a single `<iframe` when maintaining that page.
