# 0009. Action on the map, scores in the sidebars

Status: accepted

## Context

The first interface was a single side panel that held everything: scores, dice, buttons, results and a paragraph of instructions. Players had to look away from the battle to see it, could not tell the two kingdoms' scores apart, and did not discover how to move soldiers.

## Decision

- Everything that is happening now is shown on the map at the region it concerns: move and attack buttons on the neighbours of the selected region, the dice and roll controls at the attacked region, results, toasts, and plague and revolt notices.
- Each kingdom has its own sidebar, Crimson on the left and Azure on the right, with its region and soldier counts as plain numbers. The turn controls sit in the sidebar of the kingdom whose turn it is.
- Text is kept to one or two words. State is shown with colour, markers and chips; chips explain themselves in a tooltip.
- An action that is not allowed is still offered, and trying it shows a short reason.

## Consequences

- Controls are free-floating and positioned from region coordinates, so they must be clamped to the map area and can overlap a neighbouring badge.
- On-map buttons are rebuilt only when the selection or the neighbours' owners change, so a refresh never destroys a button mid-click.
- A banner in the strip of sea above the island announces each turn with a short summary.
