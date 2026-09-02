# Timing Chart

This tab displays and edits the waveforms created from the form. Click or drag to change bits, and add comments or omission marks. Edits are stored in JSON / JPEG / XLSX / HTML exports.

> For large structural changes, regenerate with Template on the form, or edit only a selected range from the context menu.

---

## Toolbar

The bar above the chart:

| Control | Description |
| --- | --- |
| **Lock icon** | Lock editing. While locked you cannot toggle bits, insert/delete, or reorder rows (zoom and comments still work) |
| **Unit** | Horizontal axis. Off = **step**, on = **ms** |
| **Labels** | Show or hide time numbers along the bottom |
| **Edit grid** | **ms** only. Drag grid boundaries to change each step’s duration, then click **Done** |
| **Undo / Redo** | Undo / redo edits (also Ctrl+Z / Ctrl+Y) |
| **Zoom out / Zoom in** | Zoom around the view center. The current scale is shown as a percentage |
| **Fit** | Fit the whole chart in the view |
| **Fit sel** | Zoom so the selection fills the view (selection required) |
| **Sel** | Selection length in milliseconds (ms mode) or steps (step mode) |

---

## Mouse

| Action | Effect |
| --- | --- |
| **Click a waveform cell** | Toggle 0 / 1. If a range is selected, every cell in the range toggles |
| **Drag** | Rectangular selection (rows × time) |
| **Drag a left-side label** | Reorder rows |
| **Drag a comment box** | Move the comment. Drop it above or below the chart |
| **Right-click** | Context menu for waveform, label, or comment |
| **Ctrl / Cmd + wheel** | Zoom centered on the pointer |
| **Move the pointer to the bottom edge** | When zoomed in, a horizontal scrollbar appears; drag the thumb to pan |

Unlock the padlock if clicks on the waveform do nothing.

---

## Keyboard

Click the chart first so it has focus.

### Pan

| Key | Action |
| --- | --- |
| **← / →** | Pan. Hold **Shift** to move faster |
| **PageUp / PageDown** | Pan by one viewport |
| **Home / End** | Jump to start / end |

### Edit

| Key | Action |
| --- | --- |
| **Ctrl / Cmd + Z** | Undo |
| **Ctrl / Cmd + Y** | Redo |
| **Ctrl / Cmd + A** | Select all signals and all time |
| **0** | Set the selection to 0 |
| **1** | Set the selection to 1 |

---

## Context menu (waveform)

Right-click on the waveform (not on a label or comment). Items depend on whether a selection exists. Waveform-changing items are hidden while editing is locked.

| Item | Description |
| --- | --- |
| **Insert zeros** | Insert columns of 0 over the selected time span and shift the rest to the right |
| **Duplicate to tail** | Copy the selection to the end of the chart |
| **Select all signals** | Select every row and time (same as Ctrl+A) |
| **Delete selection** | Clear values in the selection (length stays the same) |
| **Delete selected columns** | Remove the selected time columns and shorten the chart |
| **Add comment** | Add a comment at the click (or a range comment if a range is selected) |
| **Draw omission mark** | Draw a wavy omission over the selected time (for long idle stretches) |

---

## Signal label properties

Right-click a name on the left → **Properties**.

| Field | Description |
| --- | --- |
| **Label** | Display name. Auxiliary signals can be renamed here (empty or duplicate names are rejected) |
| **Color** | Line color for auxiliary signals |
| **Show IO number** | Per-row port-number prefix. Disabled while **Show IO numbers** is off in Preferences |

---

## Comments

Place notes above or below the waveforms.

### Add and edit

1. Right-click the waveform → **Add comment** (select a range first for a range comment)
2. Enter text and confirm
3. Drag the box. Moving it upward places it on top of the chart; downward places it below

Right-click a comment box:

| Item | Description |
| --- | --- |
| **Edit comment** | Change the text. You can select part of the text and apply **Selection color** |
| **Delete comment** | Remove it |
| **Turn horizontal arrow OFF / ON** | Horizontal arrow vs. an arrow aimed at a row |
| **Set arrow tip to this row** | When the arrow is not horizontal, point it at the row you right-clicked |
| **Properties** | Appearance |

### Properties

| Field | Description |
| --- | --- |
| **Font size / Bold** | Size (8–40) and bold |
| **Border / Background / Text color** | Box border (transparent allowed), fill, and text |
| **Dashed line color / visibility** | Dotted line from the comment to the time position |
| **Arrow color / visibility** | Pointer to the referenced time or row |
| **Wrap width** | Line width before wrapping |
| **Max lines** | Line limit, or unlimited |
| **Ellipsis (...)** | Truncate overflow with `...` |

Default dashed-line and arrow colors are also in **Preferences → Chart**. Per-comment properties override them.

---

## Omission marks

Collapse a long steady interval visually.

1. Drag to select the time range
2. Right-click → **Draw omission mark**

Change the color under **Preferences → Chart → Omission mark color**.

---

## Time unit and Edit grid

- **step** — one cell is one step; columns are even.
- **ms** — each step has a duration in milliseconds. .ziq import fills this from the log.

In **ms** mode, **Edit grid** lets you drag (or tap) vertical boundaries to change step lengths. Click **Done** when finished. Switching back to step ends grid editing.

---

## Undo / Redo and lock

- Bit toggles, insert/delete, row reorder, and comment changes support Undo / Redo.
- Lock the chart to avoid accidental edits during review or screen sharing.

---

## Exporting images and spreadsheets

Finish layout on this tab, then use the left menu.

| Format | Best for |
| --- | --- |
| **JPEG** | Slides and email. Zoom and comments are captured as shown |
| **XLSX** | Sharing waveforms in Excel as border drawings; comment border colors are preserved when possible |
| **JSON** | Re-open later in this app |

> After changing the form, click **Update Chart** before export so the file matches the screen.
