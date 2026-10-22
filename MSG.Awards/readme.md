# Four-Quadrant Digital Sign

This project is a general-purpose, Google Slides driven digital sign for a **4K landscape display (3840 × 2160)**. It divides the screen into four independent sections, allowing announcements, schedules, instructions, photographs, or other information to run side by side.

**Content owners work in Google Slides.** They can update names and photos, redesign slides, add or remove pages, and reorder content without editing the kiosk's HTML or PowerShell scripts. A Google Sheet controls how long each section displays each slide.

## What appears on the screen

Each quadrant occupies 1920 × 1080 pixels and uses its own presentation:

| Screen position | Local image folder | Timing cell in Google Sheets |
| --- | --- | --- |
| Top left | `C:\www\images\TopLeft` | `B2` |
| Top right | `C:\www\images\TopRight` | `C2` |
| Bottom left | `C:\www\images\BottomLeft` | `B3` |
| Bottom right | `C:\www\images\BottomRight` | `C3` |

Each section automatically adapts to the number of images generated from its presentation:

| Images in a quadrant's folder | Display behavior |
| --- | --- |
| None | Blank black section |
| One | Static image; no slideshow or progress bar |
| Two or more | Continuous slideshow with a progress bar along the bottom |

Slides change instantly, without fades. Each quadrant advances independently and returns to its first slide after its last slide. Images retain their original proportions and fit entirely inside their section; unused space is black.

## Updating content in Google Slides

1. Open the presentation assigned to the section you want to update.
2. Edit the content using the normal Google Slides tools.
3. Add, duplicate, delete, or reorder slides as needed.
4. Allow Google Slides to finish saving.
5. Run the kiosk's configured refresh process, or wait for its next scheduled refresh if one has been set up.

The next successful refresh downloads the updated presentations, creates new images, rebuilds the display page, and reloads Microsoft Edge.

**Edits are applied during a refresh. The kiosk does not stream the live Google Slides editor.** Simply saving a presentation does not immediately change the already running display.

### How flexible is it?

Users control the design of each slide: text, fonts, colors, backgrounds, photographs, logos, shapes, tables, and other content that appears in the exported PDF. Users can create their own layouts and templates directly in Google Slides.

For example, a content owner could:

- Update text and photographs while keeping an existing design.
- Duplicate a slide to add another announcement, event, or information page.
- Reorder slides to change the sequence shown on screen.
- Keep one section on a single permanent information slide while other sections rotate through several slides.
- Use different slide counts and display durations in all four sections.
- Repurpose a presentation for schedules, instructions, event information, or other content without rebuilding the application.

The layout is fixed at four quadrants, but the content inside each quadrant is designed by the user. There is no hard-coded slide count in the HTML builder; practical capacity depends on available memory, image sizes, and refresh time.

Use **16:9 widescreen slides** to match each quadrant. Other page proportions will fit without stretching, with black space around the image as necessary. Use large text and clear photographs so the slides remain readable at the intended viewing distance.

### Important content rules

- **Every PDF page is converted, including slide 1.** In this version, slide 1 is displayed content; it is not reserved for instructions.
- Presentations become still images. Google Slides animations, transitions, embedded video playback, audio, and clickable interactions do not carry through this PDF-to-PNG workflow.
- One duration applies to every slide within a quadrant. Google Slides presentation timings and individual-slide durations are not used.
- Removing a slide from a deck removes its generated counterpart after a successful conversion, because the converter clears old `slide-*.png` files before generating replacements.
- A blank slide still produces an image and occupies a place in the rotation. The zero-image behavior refers to the local folder containing no PNGs.

## Adjusting slideshow speed

[Open the timing spreadsheet](https://docs.google.com/spreadsheets/d/1w5-EreROT-A7kaAmCkHgKQWA6r8JlrZ6Ot1tyOCagx8/edit).

Enter a positive number of **seconds per slide** in the cell associated with each quadrant. For example, `10` displays each slide in that section for approximately ten seconds. A section with six slides at ten seconds per slide completes a rotation in approximately one minute.

Use valid positive numeric values; the current builder does not provide validation or fallback durations. Timing changes take effect when the HTML is rebuilt and reloaded during a refresh. A section containing one image remains static regardless of its timing value.

## How it works

The refresh pipeline is:

1. **Show loading feedback.** `refresh.ps1` closes Edge and opens the local loading page in full-screen kiosk mode.
2. **Download presentations.** `DL-PDF2PNG.ps1` exports each configured Google Slides presentation as a PDF.
3. **Generate local images.** ImageMagick, with Ghostscript available for PDF decoding, converts the PDFs into numbered PNG files. Downloads run sequentially while conversions are dispatched to background PowerShell jobs. Failed operations have retry handling.
4. **Build one display page.** `Build-index-html.ps1` reads the timing spreadsheet and each quadrant's PNG files, then writes `C:\www\index.html` with embedded CSS and JavaScript. Images are sorted by filename, preserving the numbered export order.
5. **Reload the sign.** `refresh.ps1` closes the loading window and launches the generated page in Edge kiosk mode.

Playback uses local HTML and PNG files. No web server, PowerPoint installation, live Google Slides embed, iframe layout, or externally hosted JavaScript library is needed for the generated slideshow. Internet access is required to download updated presentations and timing values; existing generated content can play locally without an internet connection.

## Project files

| File | Purpose |
| --- | --- |
| `loading.html` | Loading screen shown while content is being refreshed |
| `scripts/DL-PDF2PNG.ps1` | Presentation links, PDF downloads, PNG conversion, and retries |
| `scripts/Build-index-html.ps1` | Four-quadrant layout, image discovery, timing download, and HTML generation |
| `scripts/refresh.ps1` | Loading screen, content refresh, page generation, and Edge restart |
| `scripts/git-it.ps1` | Downloads the repository and copies the configured project folder into `C:\www` |

The PDFs are stored inside each quadrant folder's `pdf` subfolder as `slides.pdf`. Generated images are stored in the quadrant folder itself as `slide-000.png`, `slide-001.png`, and so on. The generated `index.html` is created on the kiosk rather than supplied as a static project page.

## Initial setup and administration

The kiosk requires Windows, Microsoft Edge, PowerShell, ImageMagick (`magick` available on PATH), and Ghostscript. Git is needed if using `git-it.ps1` to download the project.

1. Place the project contents in `C:\www`, with scripts in `C:\www\scripts`.
2. Confirm the four presentation links in `DL-PDF2PNG.ps1` and the spreadsheet ID, worksheet ID, and cell mappings in `Build-index-html.ps1`.
3. Ensure the kiosk can download the presentation PDF exports and spreadsheet CSV without an interactive sign-in. Content editors separately need editing access to the relevant Google files.
4. Configure the screen for 3840 × 2160 landscape output and verify Windows scaling and browser zoom produce the intended full layout. The current page uses fixed pixel dimensions rather than automatic responsive scaling.
5. Run `C:\www\scripts\refresh.ps1` in the kiosk user's interactive Windows session, using a PowerShell execution policy that permits the scripts.
6. If desired, configure Task Scheduler or a local button to run that refresh script. The repository does not create those triggers automatically.

Verify the Edge executable path in `refresh.ps1` matches the installation. The script controls Edge processes, so it is intended for a dedicated kiosk session. The repository download helper is separate from the content refresh: `refresh.ps1` does not run `git-it.ps1`.

### Adapting the sign for another team

An administrator can copy or create four Google Slides decks, replace the presentation URLs, and point the builder at a suitable timing spreadsheet. Once configured, content owners can maintain those decks and timing cells without routine code changes.

Changes to the number or placement of quadrants, output resolution, folder paths, transition behavior, or support for moving media require changes to the scripts or generated page logic.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Google Slides changes are not visible | Confirm edits finished saving, the correct deck is configured, and a full refresh completed successfully. Reloading HTML alone does not download new slides. |
| A section is static | One PNG produces a static image by design. Check the exported deck and generated image count. |
| A section is blank | Check its PNG folder and the download/conversion output. Empty folders intentionally produce black sections. |
| Slides advance too quickly or unpredictably | Check the quadrant's timing cell for a valid positive number of seconds. |
| Content has black space around it | Use a 16:9 deck; the page preserves image proportions instead of cropping or stretching. |
| Downloads fail | Check connectivity and whether the Google files allow unattended export from the kiosk. |
| PDF conversion fails | Confirm ImageMagick and Ghostscript are installed and `magick` is accessible to the account running the script. |
| Only part of the layout is visible | Check display resolution, Windows scaling, and browser zoom against the fixed 3840 × 2160 page. |

The current refresh process is not an atomic content update with automatic rollback. Conversion clears previous generated slide images, and refresh can continue after a child script reports an error. Review script output when a refresh fails rather than assuming the previous complete display was preserved.
