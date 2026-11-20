# 0010. Scenery is cosmetic

Status: accepted

## Context

The map looked flat and uniform. Gradients, a colour scheme, mountains and rivers were asked for.

## Decision

`scenery.gd` generates heights from distance to the coast plus noise, marks the highest cells as mountains, a second noise as forests, and lets up to three rivers flow downhill to the sea. `map_view.gd` uses it for terrain colours and decorations. Owned regions keep their kingdom colour, shaded by the terrain underneath. None of it is read by the rules.

## Consequences

- Terrain can be changed freely without affecting balance or tests.
- Mountains and rivers do not block or slow anything, which players may expect them to.
- Scenery uses the game's random generator after the map is built, so it does not change which map a seed produces.
