# CPTS Awards Digital Sign

A full-screen, 4K landscape awards display for 673 CPTS. Leadership, yearly award winners, quarterly award winners, and team awards share one animated screen over a dark night sky with an hour-long 4K fireworks video.

The display runs locally in Microsoft Edge kiosk mode. PowerShell downloads Google Slides presentations, converts them into images, and builds a single `index.html` containing all of the display regions. No web server is required.

## What the display looks like

The page uses a fixed **3840 × 2160** layout.

| Area | Content | Presentation |
| --- | --- | --- |
| Top left | Leadership and the official logo | Four leadership images surround a large central logo, with leadership and presentation graphics. |
| Top right | Yearly award winners | A large animated slideshow with a synchronized vertical sidebar showing award imagery. |
| Far bottom left — “Who” | Team awards | A dedicated slideshow using WebGL transitions. This is separate from the four quarterly cubes. |
| Across the lower portion, to the right of team awards | Quarterly award winners | Four rotating cubes labeled Q1, Q2, Q3, and Q4, with American-flag backgrounds, shadows, and parallax movement. |
| Behind the foreground content | Fireworks | An hour-long 4K video of fireworks against a dark night sky, playing automatically, muted, and on repeat. |

The four quarterly cubes provide a rolling year of recognition. **Each quarter's winners remain on display for a whole year, until new winners replace that same quarter.** Updating Q1 does not require clearing Q2, Q3, or Q4.

This retention is managed through the content of the quarterly presentations; the scripts do not calculate expiration dates or automatically remove winners when the calendar year changes.

## How it is made

### 1. Google Slides holds the editable content

The presentation list in [`scripts/DL-PDF2PNG.ps1`](scripts/DL-PDF2PNG.ps1) maps Google Slides decks to local folders:

| Deck / folder | Purpose |
| --- | --- |
| `Leadership` | Four leadership images in the top-left area. |
| `Quarter1` | Q1 award winners. |
| `Quarter2` | Q2 award winners. |
| `Quarter3` | Q3 award winners. |
| `Quarter4` | Q4 award winners. |
| `Year` | Main yearly-awards slideshow. |
| `YearSideBar` | Companion imagery for the yearly-awards sidebar. |
| `Who` | Team-awards slideshow in the far bottom-left corner. |

**Slide 1 of every presentation is reserved for instructions and is not displayed.** PDF page 2 becomes `slide-000.png`, page 3 becomes `slide-001.png`, and so on.

Leadership uses the first four generated images, `slide-000.png` through `slide-003.png`, in fixed positions. The award slideshows load the PNG files found in their respective folders, sorted by filename. Keep `Year` and `YearSideBar` aligned in content order and, preferably, slide count so the synchronized views correspond.

### 2. PowerShell downloads PDFs and generates PNGs

`DL-PDF2PNG.ps1` exports each configured Google Slides presentation as a PDF and saves it under:

```text
C:\www\images\<DeckName>\pdf\slides.pdf
```

It then launches background PowerShell jobs that run ImageMagick to render the PDFs at 288 DPI. The conversion discards the first page, flattens transparency against white, and writes numbered PNGs into the deck's parent folder:

```text
C:\www\images\<DeckName>\slide-000.png
C:\www\images\<DeckName>\slide-001.png
```

Old `slide-*.png` files are removed before each conversion attempt so deleted presentation slides do not remain in the normal generated sequence. Download and conversion failures are retried, with additional download cycles for failed decks.

### 3. PowerShell builds one HTML page

[`scripts/Build-Index-Html.ps1`](scripts/Build-Index-Html.ps1) scans the image folders and writes `C:\www\index.html`.

The generated page combines the leadership images, logo, decorative graphics, video, and all six slider regions directly in one document. **There are no slideshow iframes**, even though some CSS class names retain the `iframe-` prefix from the layout.

The page uses bundled local libraries:

| Component | Implementation |
| --- | --- |
| Quarterly cubes | Swiper 11 with the cube effect, shadows, and parallax; 3-second autoplay delay and 800 ms transitions. |
| Team awards | Swiper 11 with the Swiper GL module and 1,200 ms transitions. |
| Yearly awards | Swiper 6 with parallax; 14-second autoplay delay and 1,000 ms transitions. |
| Yearly sidebar | A synchronized vertical Swiper 6 slider showing five slides at a time. |
| Fireworks | An HTML video element loading `videos/1hour.webm`. |

Both Swiper versions are retained because the existing display components use different implementations. All six bundled JS/CSS files are required; the builder checks for them before overwriting `index.html`.

Building from existing local PNGs and playing the finished display are offline operations. Downloading updated presentations or repository files requires network access.

## Files and dependencies

Deploy the **contents** of `CPTS.Awards` into `C:\www`, so the scripts are located at `C:\www\scripts`.

| Path | Role |
| --- | --- |
| `scripts/DL-PDF2PNG.ps1` | Downloads presentation PDFs and converts them into PNGs. |
| `scripts/Build-Index-Html.ps1` | Generates the combined awards display. |
| `scripts/refresh.ps1` | Shows the loading screen, updates slides, rebuilds the page, and restarts Edge. |
| `scripts/startupkiosk.ps1` | Opens the existing `index.html` in Edge kiosk mode. |
| `scripts/silentkiosk.vbs` | Runs the startup script with its PowerShell window hidden. |
| `scripts/git-it.ps1` | Downloads the repository and copies the `CPTS.Awards` files into `C:\www`. |
| `scripts/swiper-*.js` and `scripts/swiper-*.css` | Local slideshow dependencies. |
| `images/` | Included logo, headings, quarter labels, flag background, and other static graphics. |
| `images/<DeckName>/` | Generated presentation images and downloaded PDFs. |
| `loading.html` | Green Matrix-style loading animation shown during refresh. |
| `videos/1hour.webm` | Separately supplied fireworks background video. |
| `index.html` | Generated display page. |

The repository does not include the fireworks video or the generated presentation folders and final `index.html`. Supply the video and run the content/build scripts before launching the completed display.

The kiosk needs:

- Windows with Microsoft Edge and PowerShell.
- ImageMagick with `magick` available on the executable search path.
- Ghostscript for ImageMagick's PDF rendering.
- Git if using `git-it.ps1` for repository updates.
- A 4K landscape display and graphics support for WebGL and 4K video playback.
- Google Slides decks accessible to the script's unauthenticated PDF export requests.

## Initial setup

1. Copy the project contents into `C:\www`.
2. Install ImageMagick and Ghostscript. Open a new PowerShell session after installation so updated executable paths are available.
3. Place the hour-long 4K fireworks video at `C:\www\videos\1hour.webm`.
4. Review the presentation URLs in `C:\www\scripts\DL-PDF2PNG.ps1` and confirm access to each deck.
5. Reserve slide 1 in every deck for instructions. Add the display content starting on slide 2; the leadership deck needs four display slides.
6. Download the content and build the display:

   ```powershell
   & "C:\www\scripts\DL-PDF2PNG.ps1"
   & "C:\www\scripts\Build-Index-Html.ps1"
   ```

7. Launch the kiosk:

   ```powershell
   & "C:\www\scripts\startupkiosk.ps1"
   ```

The launch scripts expect Edge at `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`. Adjust that path if the installation differs.

Use a 3840 × 2160 browser viewport: the layout is fixed in pixels rather than responsive. Windows display scaling and browser zoom affect how much fits on screen; 100% scaling and 100% browser zoom are the starting configuration for this layout.

## Updating the display

Edit the relevant Google Slides deck, then run:

```powershell
& "C:\www\scripts\refresh.ps1"
```

The refresh script closes Edge, opens the loading screen, downloads and converts the presentations, rebuilds `index.html`, and relaunches the awards display. It closes all Edge processes on the machine and clears the current user's default Edge session files, so it is intended for the dedicated kiosk.

For quarterly updates, replace only the presentation content for the quarter receiving new winners. Leave the other quarterly decks populated until their replacement winners are available.

For a layout-only rebuild using existing PNGs:

```powershell
& "C:\www\scripts\Build-Index-Html.ps1"
```

Reload the display afterward to load the newly generated page. Make lasting layout or animation changes in `Build-Index-Html.ps1`; directly editing `index.html` will be overwritten by the next build.

`git-it.ps1` updates project files separately; it is not called by `refresh.ps1`. Its Robocopy operation leaves destination files that are absent from the repository in place, including locally supplied media and generated content. It is not a mirror/purge operation.

## Operational notes

- The startup script opens the last built display; it does not download content or generate HTML.
- The builder accepts `-RootPath` for an alternate output root, but the downloader and kiosk scripts still contain `C:\www` paths that must be updated separately.
- Empty slideshow folders produce warnings and no slide markup. Populate the folders and rebuild if a region is missing.
- Yearly awards need images in both `Year` and `YearSideBar` for their sliders to initialize.
- Conversion flattens slide images against white. Transparent space around foreground elements can reveal the fireworks, but the team/year panels use black backgrounds and their images can cover or crop to fill their regions.
- The repository asset is named `Whois.png`, while the generated page references `WhoIs.png`. This works on the intended case-insensitive Windows filesystem; match the capitalization if adapting the project to a case-sensitive host.
- Scheduling is configured outside these scripts. Run the browser-launch portion in the logged-in kiosk user's session so the window appears on the display.

## Project source

[CPTS.Awards in the DigitalSign repository](https://github.com/673cpts-design/DigitalSign/tree/main/CPTS.Awards)
