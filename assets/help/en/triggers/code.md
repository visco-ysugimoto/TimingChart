# Code Trigger

Several inputs are used together as a **binary code** to load, run, or unload tasks. Control code, group number, and task number are encoded as bit patterns.

## How to run a command

1. Set the control, group, and task bits
2. Turn **input 1 (trigger) ON** to execute
3. Turn input 1 OFF before setting the next code

The next code is not accepted until the trigger is released.

## Bit assignment

The mapping depends on the input port count. **Input 1 is always the trigger.** Control / Group / Task names are fixed. The combined signal `CODE_OPTION` is the logical OR of those bits.

### 32 ports

| Role | Input ports | Bits | Meaning |
| --- | --- | ---: | --- |
| Trigger | Input 1 | — | Latch and execute the code |
| Control Code | Inputs 2–9 | 8 | Command type |
| Group | Inputs 10–15 | 6 | Group number (1–50 as binary) |
| Task | Inputs 16–21 | 6 | Task number (1–50 as binary) |

Each 6-bit field is converted to decimal and mapped to numbers 1–50.

### 16 ports

| Role | Input ports | Bits |
| --- | --- | ---: |
| Trigger | Input 1 | — |
| Control Code | Inputs 2–5 | 4 |
| Group | Inputs 6–8 | 3 |
| Task | Inputs 9–14 | 6 |

## Control codes (decimal / 8-bit)

Set the code, then turn input 1 (trigger) ON to execute.
The 8-bit pattern is Input 9 → Input 2 (MSB on the left). That is the 8-bit value the controller must drive.

| Decimal | 8-bit | Command |
| ---: | --- | --- |
| 1 | `00000001` | Run task |
| 2 | `00000010` | Run system command |
| 3 | `00000011` | Switch active task |
| 4 | `00000100` | Load task |
| 5 | `00000101` | Unload task |
| 9 | `00001001` | Run active task |
| 10 | `00001010` | Clear judgment counters |
| 12 | `00001100` | Unload all tasks |
| 34 | `00100010` | Lot start |
| 35 | `00100011` | Lot end |
| 37 | `00100101` | Image save start |
| 38 | `00100110` | Image save end |
| 39 | `00100111` | Save image file |
| 40 | `00101000` | Edit lot settings |
| 42 | `00101010` | System shutdown |
| 43 | `00101011` | Save screen file |
| 44 | `00101100` | Screen save start |
| 45 | `00101101` | Screen save end |
| 48 | `00110000` | Distributed operation start |
| 49 | `00110001` | Distributed operation end |

## Example

Load and run group 10 / task 5 (**32-port** layout).
Each step is “set the code with trigger OFF → turn trigger ON to execute”.

Bit order:

- Control code: Input 2 is LSB, Input 9 is MSB (8 bits)
- Group: Input 10 is LSB, Input 15 is MSB (6 bits)
- Task: Input 16 is LSB, Input 21 is MSB (6 bits)

| Step | Action | Control code | Group | Task | Trigger (Input 1) | Inputs to turn ON |
| ---: | --- | ---: | ---: | ---: | --- | --- |
| 1 | Set unload-all-tasks | 12 (`00001100`) | 0 | 0 | OFF | Inputs 4, 5 |
| 2 | Execute unload-all-tasks | 12 (`00001100`) | 0 | 0 | ON | Inputs 1, 4, 5 |
| 3 | Set load task | 4 (`00000100`) | 10 (`001010`) | 5 (`000101`) | OFF | Inputs 4, 11, 13, 16, 18 |
| 4 | Execute load task | 4 (`00000100`) | 10 (`001010`) | 5 (`000101`) | ON | Inputs 1, 4, 11, 13, 16, 18 |
| 5 | Set run task | 1 (`00000001`) | 10 (`001010`) | 5 (`000101`) | OFF | Inputs 2, 11, 13, 16, 18 |
| 6 | Execute run task | 1 (`00000001`) | 10 (`001010`) | 5 (`000101`) | ON | Inputs 1, 2, 11, 13, 16, 18 |
| 7 | Turn trigger OFF | 1 (`00000001`) | 10 (`001010`) | 5 (`000101`) | OFF | Inputs 2, 11, 13, 16, 18 |
| 8 | Run the same code again | 1 (`00000001`) | 10 (`001010`) | 5 (`000101`) | ON | Inputs 1, 2, 11, 13, 16, 18 |

Control codes 12 / 4 / 1 match “Unload all tasks”, “Load task”, and “Run task” in the table above.
Binary values such as `00001100` are written Input 9 → Input 2 (MSB on the left).
