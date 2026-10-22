MOVE TO C:\www\QwenVoice

1. Stop announcement generation and any scheduled task that runs it.
2. Move the ENTIRE C:\QwenVoice folder to C:\www\QwenVoice, including models,
   Voice, cache, settings.json, references, and the existing .venv folder.
3. Extract this ZIP into C:\www\QwenVoice. It contains only TXT files for email.
4. Rename Restore-Filenames.cmd.txt to Restore-Filenames.cmd and run it.
   This restores .ps1/.py/.cmd extensions and replaces the matching scripts.
   Existing scripts are backed up with .before-path-update suffixes.
5. Run Repair-After-Move.cmd once. Internet is required to rebuild Python's
   environment. Installed Python 3.11 must remain available on this computer.
   The repair preserves the old environment as .venv-before-move-TIMESTAMP,
   recreates .venv, installs dependencies and checks locally stored models.
   Model files and cached voices are retained; repair skips model downloads.
   If setup fails, fix the reported error and rerun Repair-After-Move.cmd.
6. Run Update-Announcement.cmd and check the generated message.
7. Update scheduled tasks, shortcuts, or X-keys scripts that still call the old
   folder. They are external Windows configuration and cannot be edited by ZIP.

Scheduled task action examples:
Program: powershell.exe (or pwsh.exe)
Arguments: -NoProfile -ExecutionPolicy Bypass -File "C:\www\QwenVoice\Update-Announcement.ps1"
Start in: C:\www\QwenVoice

Direct Python generation task:
Program: C:\www\QwenVoice\.venv\Scripts\python.exe
Arguments: "C:\www\QwenVoice\generate.py"
Start in: C:\www\QwenVoice

EXTERNAL EDGE BUTTON SCRIPT
external\closed-button.ps1.txt is the updated launcher based on your screenshots.
The filename restorer renames this too. Copy external\closed-button.ps1 into
its current button-script location if you want that full replacement.
It generates successfully before restarting Edge in the current Windows session.
Alternatively change only the updater call in your existing button script to:
& "C:\www\QwenVoice\Update-Announcement.ps1"
Your working Edge autoplay policy remains unchanged. No new browser profile.

PATHS AND SETTINGS
Update-Announcement.ps1 defaults to its own folder ($PSScriptRoot).
Launchers and Python scripts find adjacent files relative to themselves.
Repair converts settings.json paths beginning with C:\QwenVoice\ into relative
paths, preserving all other settings and saving a backup before any change.
Voice selection now stores relative paths such as Voice\Casey Kasem\reference.mp3.
Output of the Sheets updater remains C:\www\message.wav and C:\www\closed.html.
Manual Generate.cmd retains your existing output setting; relative output.wav
now means C:\www\QwenVoice\output.wav.
The complete volume-normalizing generator and voice-selection helpers are included.
No settings.json, voice samples, script.txt or reference.txt template is included,
so your configuration and recordings are not replaced.
After successful testing you may remove .venv-before-move-* to reclaim space.

VALIDATION
Python files compile; path and feature-preservation checks passed.
Actual Windows environment recreation, GPU generation and Edge launch must be
verified on your computer. Do not run generation while moving/repairing files.
