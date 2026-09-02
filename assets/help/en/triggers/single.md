# Single Contact Trigger (Single Trigger)

During automatic operation, a **rising edge (Lo→Hi)** on an assigned input starts the task or system command bound to that contact.

**One input maps to one task.** The first input is `TRIGGER`.

## Characteristics

- Wiring is easy to follow: one contact, one job
- The number of product / task variants is limited by the number of contacts

## Example

The same input (input 1) starts different tasks on successive rising edges.

| Step | Action |
| ---: | --- |
| 1 | Input 1 starts inspection for group 01 / task 01 (G01T01) |
| 2 | Input 1 starts inspection for group 01 / task 05 (G01T05) |
| 3 | Input 1 starts G01T01 again |
| 4 | Input 1 starts G01T05 again |

Which task is bound to which contact is defined on the machine.

## Typical 32-input layout (VTV9000)

| Input | Typical use |
| ---: | --- |
| 1–10 | Task start triggers (Task G01T01–G01T10, and similar) |
| 11–19 | Extra trigger inputs |
| 22–29 | Camera-column run control (Cam1–Cam8) |
| 30 | Release contact-input wait |
| 32 | System keep-running signal |
