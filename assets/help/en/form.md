# Input Form

This tab defines **which signals** appear on the chart and **in what order cameras capture**. The top row is global settings, the lower left is signal names, and the lower right is the Camera Configuration Table.

---

## Recommended workflow

| Step | What to do |
| ---: | --- |
| 1 | Set Trigger Option, PLC/EIP, port counts, and camera count |
| 2 | Enter signal names on the left (suggestions are available) |
| 3 | Set each camera’s capture mode in the table on the right |
| 4 | Click **Template** and check the Timing Chart tab |
| 5 | After later edits, click **Update Chart** to apply them |

> Update Chart is disabled until a chart exists (Template or import) and at least one visible signal name is filled in.

---

## Top settings

| Field | Choices | Meaning |
| --- | --- | --- |
| **Trigger Option** | Single / Code / Command | Trigger mode. Code Trigger is hidden when Input Port is 6 |
| **PLC / EIP** | None / PLC / EIP | Whether to use PLC or EtherNet/IP channels |
| **Input Port** | 6 / 16 / 32 / 64 | Number of input signals |
| **Output Port** | 6 / 16 / 32 / 64 | Number of output signals |
| **HW Port** | 0, or the same as Camera | 0 disables HW triggers. Matching Camera gives one HW line per camera |
| **Camera** | 1–8 | Camera count; also the number of table columns |

### Trigger Option

| Mode | Typical use |
| --- | --- |
| **Single Trigger** | Ordinary single-shot trigger. The first input is treated as TRIGGER |
| **Code Trigger** | Group/task selection by code. Those input names are locked. An auxiliary `CODE_OPTION` signal is added automatically |
| **Command Trigger** | Command-style trigger. Auxiliary signals such as `Command Option` are generated |

### When PLC / EIP is selected

Input and output headers show tabs: **DI / PLI/ESI** and **DO / PLO/ESO**.

- **DI / DO** — device DIO
- **PLI / PLO** — PLC (when PLC is selected)
- **ESI / ESO** — EtherNet/IP (when EIP is selected)

**DI⇔PLI/ESI** and **DO⇔PLO/ESO** appear on the right. They swap names between the DIO list and the PLC/EIP list in the same order.

---

## Buttons

| Button | Action |
| --- | --- |
| **Clear** | Clears names and related form fields (confirm before using) |
| **Template** | **Creates a new** waveform from the current form and camera table |
| **Update Chart** | Applies form changes to the **existing** chart, keeping manual waveform edits when possible |
| **DI⇔PLI/ESI** / **DO⇔PLO/ESO** | PLC/EIP only. Swap DIO and PLC/EIP names |

> If you want the exported file to match the form, click Update Chart before exporting.

---

## Signal names

Three columns: **Input Signals**, **Output Signals**, and **HW Trigger Signals**. **Auxiliary Signals** sit under HW Trigger.

### Common controls

| Action | Description |
| --- | --- |
| **Typing** | Enter a name. Pick from suggestions. Avoid duplicate names |
| **Checkbox on the right** | Only checked signals appear on the chart |
| **Tab / Shift+Tab** | Move to the next / previous field |
| **Enter** | Commit the field (behavior depends on the control) |

Suggestion lists follow the UI language (Japanese / English).

### Input / Output

- Increasing the port count adds fields; decreasing removes them from the end.
- In Code Trigger mode, control / group / task inputs are greyed out and locked.

### HW Trigger

- When **HW Port is 0**, the panel shows “HW Trigger Ports are not available.” and the table cannot use HW Trigger mode.
- When HW Port matches Camera, you can name one HW trigger per camera.

### Auxiliary Signals

Extra lines that are not DIO (for example BUSY).

| Action | Description |
| --- | --- |
| **Add** | Add one auxiliary signal |
| **Remove** | Delete that row |
| Checkbox | Show / hide on the chart |

Code / Command Trigger may add helpers such as `CODE_OPTION` automatically. Keep names unique.

---

## Camera Configuration Table

The right-hand table defines **when each camera captures, and how**. Template builds the waveform from this table.

### Rows and columns

- Columns are Camera 1, 2, … (follows Camera count)
- Rows are capture steps. Use **Add Row** / **Remove Row** (at least one row remains)

### Cell modes

Each cell has a dropdown. Colors help you scan the table.

| Mode | Meaning |
| --- | --- |
| **None** | No capture in that step |
| **Sequential** | Software sequential capture |
| **Contact Input** | Wait for a contact input |
| **HW Trigger** | Hardware trigger (unavailable when HW Port is 0) |

### Shortcuts

| Action | Effect |
| --- | --- |
| **Click a column header (Camera n)** | Set that entire camera column to one mode |
| **Click the row number** | Toggle **Simultaneous** capture. The row turns teal; cameras in that row fire together |

> Use Simultaneous rows for multi-camera shots at the same instant, and Sequential rows for one-by-one capture.

---

## Troubleshooting

- **Update Chart is disabled** — run Template or import a file first, and enter at least one visible signal name.
- **HW Trigger is missing in the table** — set HW Port equal to the camera count.
- **Code Trigger is not in the list** — set Input Port to 16 or more (it is hidden at 6).
- **No signals on the chart** — check the visibility checkboxes, then run Template or Update Chart.
