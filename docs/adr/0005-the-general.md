# 0005. The general

Status: accepted

## Context

Without a limit, a kingdom could attack from every border region each turn, and there was no reason to concentrate forces.

## Decision

Each kingdom has one general who cannot die. Only the region holding the general can attack. The general follows a conquest into the captured region, may otherwise march to one neighbouring own region per turn, and escapes to the nearest own region if the region they stand in is lost.

## Consequences

- A kingdom fights on one front at a time; switching fronts costs turns.
- A cut-off pocket cannot attack unless the general fights a way to it.
- Defending needs no general.
- Buying additional generals is planned but not built.
