<div align="center">

# DigitalSign

### Modern digital signage. Familiar tools. Local presentation.

Turn a web browser into a polished, full-screen information display—with content that staff can maintain using familiar collaboration tools.

**Browser-based presentation · Editable content · Kiosk operation**

[The approach](#the-approach) • [How it works](#how-it-works) • [Baseline requirements](#baseline-requirements) • [Cost reference](#cost-reference)

</div>

---

## The problem

How do we modernize institutional processes while using money and manpower more efficiently, improving public perception, and supporting employee morale?

The usual answer is another app—or several apps, each with its own subscription, administration, and training requirements.

DigitalSign starts with a simpler idea: **use the presentation capabilities already built into a web browser, and let staff update the content through tools they already know.**

## The approach

Many modern applications use web technologies for their user interfaces. The same technologies can deliver a professional digital sign without requiring a separate commercial signage platform.

DigitalSign pairs reusable web presentation layouts with free-to-use collaboration tools. Running those pages in full-screen kiosk mode creates a dedicated display experience, while keeping routine content editing accessible to the people who own the information.

| Priority | Approach |
| :--- | :--- |
| **Professional presentation** | Web layouts control the visual design, placement, and presentation of content. |
| **Straightforward updates** | Staff edit content in familiar tools, such as Google Slides or Google Sheets, as supported by the selected project. |
| **Consistent appearance** | Presentation templates keep the display organized as content changes. |
| **Practical operation** | A Windows computer runs the display in browser kiosk mode, with physical buttons available for configured actions. |
| **Lower recurring overhead** | Reuse browser capabilities and existing tools to reduce dependence on paid signage subscriptions. |

## How it works

1. **Maintain the content.** Content owners update the source material used by their selected signage project.
2. **Prepare the display.** The project's scripts or integrations bring that content into its presentation layout.
3. **Present in kiosk mode.** The browser displays the finished page full-screen on a dedicated signage monitor.
4. **Operate with simple controls.** Configure the X-keys buttons for the actions needed at that installation.

Individual project folders define their own layouts, content sources, scripts, and setup instructions. Use those instructions alongside the shared baseline below.

---

## Baseline requirements

### 1. Commercial signage display

**Samsung QM32C–QM98C** commercial signage displays are the specified display baseline, with the model and size selected for the installation.

Use a model rated for **24/7 operation**. These displays are intended for continuous commercial signage use; a 24/7 rating is not a guarantee against image retention or burn-in. Follow the selected model's operating and content guidance.

[Samsung QM98C specifications](https://www.samsung.com/latin_en/business/smart-signage/uhd-4k-signage/98inch-uhd-signage-qm98c-lh98qmcebgcxza/)

### 2. Physical controls

The baseline control assembly uses one USB switch interface, one three-way splitter, and three individual push buttons.

**Supplier:** [P.I. Engineering / X-keys](https://piengineering.com/)

| Component | SKU | Quantity | Unit price | Extended price |
| :--- | :--- | ---: | ---: | ---: |
| X-keys USB 3 Switch Interface | `XK-1283-UJS3-R` | 1 | $64.95 | $64.95 |
| X-keys TRRS 3 Way Splitter Cable | `XK-A-1310-TRRS-R` | 1 | $11.50 | $11.50 |
| X-keys Transparent One Button Switch | `XK-A-1581-1BTS-R` | 3 | $39.95 | $119.85 |
| **Control assembly total** | | **5** | | **$196.30** |

Assign and label each button for its intended function at the installation. Button behavior depends on the configured macros and scripts.

### 3. MacroWorks

[MacroWorks from P.I. Engineering](https://piengineering.com/pages/macroworks) configures the X-keys controls.

| Requirement | Baseline |
| :--- | :--- |
| Installer | `MW3.1(1.1.2.58)Installer.exe` |
| Download size | 7.7 MB |
| Release updated | October 21, 2026 |
| Supported operating systems | Windows 7–11 |
| Dependency | Microsoft .NET Framework 4.8 |

The operating-system range above describes MacroWorks compatibility; the signage deployment baseline below uses Windows 11.

### 4. Automatic sign-in

**[Microsoft Sysinternals Autologon v3.10](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon)** configures automatic Windows sign-in for the designated kiosk account.

Automatic sign-in and launching the signage page are separate setup steps. Configure the browser's kiosk startup using the selected project's deployment instructions.

### 5. Windows licensing

The following purchasing references are included in the deployment baseline.

| Item | Manufacturer part number | CDW-G reference | Listed price |
| :--- | :--- | :--- | ---: |
| Windows 11 Pro for Workstations — license | `HZV-00102` | [EDC 6729570](http://www.cdwg.com/shop/products/default.aspx?EDC=6729570) | $262.19 |
| Additional Windows licensing reference¹ | `EP2-26277` | [EDC 8107756](http://www.cdwg.com/shop/products/default.aspx?EDC=8107756) | $210.66 |

¹ The supplied baseline identifies this item by part number. Confirm its exact edition, license terms, and applicability with the supplier before ordering.

### 6. Standard operating-system image

| Requirement | Baseline |
| :--- | :--- |
| Image | **ESHB - Windows 11 LTSC 11.25.02.R01** |
| Source | [EITaaS Enterprise Service Request portal](https://usaf.dps.mil/teams/EIT/SAF/EITaaS/ESR/SitePages/ESR.aspx) |

The image identifier above is the specified organizational baseline. Access to the internal portal requires the appropriate organizational access.

---

## Cost reference

| Group | Reference amount |
| :--- | ---: |
| Complete X-keys control assembly | **$196.30** |
| Windows 11 Pro for Workstations reference | $262.19 |
| Additional licensing reference — `EP2-26277` | $210.66 |

Prices are the supplied planning figures in USD, not live quotes. The display, computer, mounting hardware, cabling, taxes, and shipping are not included. Windows entries are listed separately because the applicable licensing combination depends on the deployment.

## Deploying a project

- Select the project folder that matches the intended display.
- Follow its instructions for content sources, local files, and any additional software dependencies.
- Configure Windows sign-in, browser startup, display orientation, and the required button actions.
- Verify the presentation and controls, then restart the computer to confirm the sign returns to operation as intended.

**The goal:** give staff an easy way to keep information current while delivering a consistent, professional display to the people who need it.
