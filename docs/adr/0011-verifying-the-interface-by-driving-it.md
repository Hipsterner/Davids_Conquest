# 0011. Verifying the interface by driving it

Status: accepted

## Context

Interface behaviour cannot be checked by the headless rule tests, and asking a person to click through after every change is slow.

## Decision

`tests/screenshot.gd` loads the real game in a window, pushes real mouse events at region and button positions, prints the resulting state and saves screenshots. Battle pacing is controlled by `main.pace` so long sequences run quickly.

## Consequences

- Clicks go through the same input path as a player's, including window scaling.
- Screenshots are reviewed by eye; nothing compares them automatically.
- Real mouse movement over the test window is delivered as well and can disturb hover-dependent steps.
- Tooltip popups could not be captured this way.
