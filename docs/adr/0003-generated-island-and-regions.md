# 0003. Generated island and regions

Status: accepted

## Context

A fixed map would be easy to balance but the same every game.

## Decision

Generate a new island each game. Land is a noise-perturbed rounded square on a 34 by 36 hex grid, reduced to its largest landmass. Twenty-two region origins are spread by best-candidate sampling, and regions grow from them one cell per turn in round-robin so they end up similar in size. The two regions furthest into opposite corners become the castles.

## Consequences

- Every game has a different map; balance between the two starts is not guaranteed.
- Round-robin growth replaced a single random frontier, which produced regions of only a few cells.
- Tests assert over many seeds that every region has cells, the region graph is connected and the castles are not neighbours.
