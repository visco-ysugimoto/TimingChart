# Overview

Timing Chart Generator builds **digital timing diagrams** from a form: inputs, outputs, hardware triggers, and camera capture order. You can edit the waveforms, add comments, and export JSON, JPEG, or XLSX.

Open this help with the **?** icon in the app bar, or **Help** in the left menu. The page that matches the current tab is shown first.

> **Tip:** Read **Overview** → **Input Form** → **Timing Chart** the first time you use the app.

---

## Screen layout

| Area | What it is for |
| --- | --- |
| **Input Form** tab | Trigger mode, port counts, signal names, and the camera capture table |
| **Timing Chart** tab | View and edit waveforms, comments, omission marks, and zoom |
| **Left menu (≡)** | Import / export / language / preferences / help |
| **Language badge (top right)** | Current UI language (JP / EN). You can also switch it from the menu |

---

## Typical workflow

| Step | What to do |
| ---: | --- |
| 1 | On **Input Form**, set Trigger Option, ports, signal names, and the camera table |
| 2 | Click **Template** to create the initial waveforms (required the first time) |
| 3 | Switch to **Timing Chart** and review or edit the diagram |
| 4 | After changing names or counts, click **Update Chart** to apply them to the existing chart |
| 5 | Export JSON, JPEG, or XLSX from the menu when you are done |

> **Template** generates a new waveform from the form. **Update Chart** applies form changes while keeping as much of your manual chart edits as possible. Update Chart stays disabled until you have run Template or imported a file.

---

## Left menu

Open ≡ at the top left.

### Import

| Item | Description |
| --- | --- |
| **Import** | Load a JSON file you exported earlier (settings, waveforms, and comments) |
| **Append chart to the end...** | Concatenate another JSON chart **after** the current one |
| **Import (.ziq)** | Restore form and chart from a measurement `.ziq` (zip) archive |

**Typical files inside a .ziq**

- `vxVisMgr.ini` — trigger settings and IO assignments
- `DioMonitorLog.csv` — DIO monitor log
- `Plc_DioMonitorLog.csv` / `FNL_DioMonitorLog.csv` — PLC / FNL logs when present

### Export

| Item | Description |
| --- | --- |
| **Export** | Save the current settings, waveforms, and comments as JSON (for later editing) |
| **Export chart image (JPEG)** | Save the visible chart as an image |
| **Export as XLSX** | Excel workbook. Waveforms are drawn with **cell borders** |

After a successful save, **Open folder** on the snack bar reveals the output location.

> To skip the save dialog, set a base folder and enable **Quick save** under **Preferences → I/O**.

### Append chart

Another chart is joined after the current waveforms.

- If **time units differ** (step vs ms), you are asked whether to keep the current unit.
- If the incoming file has **signals that do not exist** here, choose **Add with 0 padding** or **Do not add**.
- A join comment (default name **Appended chart**) is inserted at the boundary.

### Other items

| Item | Description |
| --- | --- |
| **English / Japanese** | Switch UI language and suggestion lists |
| **Preferences** | Display, colors, grid, and export paths |
| **Help** | Opens this dialog |
| **About** | Version and changelog |

---

## Preferences

Categories are listed on the left of the Preferences window.

### General

| Item | Description |
| --- | --- |
| **Show IO numbers** | Prefix port numbers on chart labels. Per-row overrides are available from the label properties on the chart |
| **Default camera count** | Camera count for new sessions (1–8) |

### Chart

| Item | Description |
| --- | --- |
| **Show grid lines** | Grid in the waveform area |
| **Default chart length** | Waveform length (steps) used by Template |
| **Signal colors** | Input / output / HW trigger / auxiliary line colors |
| **Comment colors** | Default dashed line, arrow, and omission colors. Individual comments can override these on the chart |

### I/O

| Item | Description |
| --- | --- |
| **Export base folder (full path)** | Folder used for quick save. If unset, a dialog is shown every time |
| **Quick save (skip dialog)** | Save immediately into the base folder |
| **Default export folder** | Subfolder name under the base folder |
| **File name prefix** | Prefix added to exported file names |

### Appearance / Language

- **Dark mode** and **Accent color** change the look of the app.
- Language can also be switched from the left menu. Input suggestions follow the selected language.
