# 0007. Aftermath of a conquest

Status: accepted

## Context

Taking a region was pure gain, so the best play was to grab everything in reach.

## Decision

A newly conquered region is marked in two ways. It is recovering: it misses the next arrival of recruits. And it is unsecure for two rounds: if it has no soldiers after any player's turn in that time, a die is rolled and on a 1 or 2 it revolts and returns to the barbarians with one soldier. One soldier keeps it safe.

## Consequences

- Over-extending with the last soldier is risky, since it leaves the new region empty.
- A revolt can cut the supply line to regions beyond it.
- A general standing in a revolting region escapes to the nearest own region.
- Unsecure regions are marked on the map with an orange outline and warning sign.
