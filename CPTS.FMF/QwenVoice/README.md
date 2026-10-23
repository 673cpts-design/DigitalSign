# FMF voice announcements

Production scripts for `C:\www\QwenVoice`. The nightly Git/Robocopy job copies
this directory from `CPTS.FMF/QwenVoice` into place.

Run **Update-Announcement.cmd** to build `C:\www\message.wav` and
`C:\www\closed.html`. The existing close-button script runs the updater and
relaunches Edge. The current FMF layout is included directly in the updater.
It uses the existing `C:\www\New-FMF-Template-I.png` overlay and Google Slides.

## Configuration

`deployment.json` contains the current Google Sheet URL. Its `web_folder` value
`..` selects `C:\www`. `settings.json` contains the production generation settings:
0.6B model, English, seed 42, 300-character chunks, 0.22-second pauses,
0.22-second startup trim, 5 ms fade, -16 LUFS normalization and -1.5 dBFS peak ceiling.
The updater fills in the selected voice paths before generating audio.

Sheet cells: A2 = message, B2 = playback Yes/No, B4 = voice name.
A10 down = ZIP links, B10 down = matching names. A voice ZIP contains reference.txt
and reference.wav or reference.mp3. Valid cached voices in `Voice` are reused
without another download. Audio is generated even when playback is No.

## Installation

On the current kiosk, keep the existing subfolders and replace the top-level
production files through the Git job. No setup rerun is required.
On a new kiosk, install 64-bit Python 3.11 with its launcher and a compatible
NVIDIA driver, then run Setup.cmd with internet access. Setup creates .venv,
installs dependencies, provisions models and checks CUDA. Run Update-Announcement.cmd
for the first announcement. Use the existing kiosk button and autoplay policy setup.

Keep `.venv`, `models`, `cache` and `Voice` local. Models and cached voices can be
copied to another kiosk; create its Python environment by running Setup there.
The Git job updates tracked JSON nightly, so permanent configuration changes belong
in the repository. Do not run manual generation concurrently with the updater.

Speech generation is local. Reading Sheets, fetching uncached voices and displaying
Google Slides require internet. Python, drivers, models and voice recordings are
not included in this source directory. Setup does not configure Windows policies,
buttons or scheduled tasks.
