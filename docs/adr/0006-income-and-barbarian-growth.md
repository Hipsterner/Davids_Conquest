# 0006. Income and barbarian growth

Status: accepted

## Context

The first version gave every owned region two soldiers every turn. Armies grew faster than the map could absorb, and barbarians either walled the players in or were irrelevant.

## Decision

- Each kingdom starts with 2 soldiers in its castle.
- From round 2 the castle gains 1 soldier every round.
- Every third round (3, 6, 9, ...) each owned region gains 2 soldiers, or 1 if it is cut off from the castle.
- Each barbarian region has a 75% chance per round of gaining a soldier, capped at 5.

## Consequences

- The opening is tight: the first attack is usually one or two soldiers against one.
- The castle soldier keeps a kingdom alive between recruit rounds.
- Barbarians are a steady obstacle but never grow past 5.
- All of these numbers are constants at the top of `rules/game_state.gd`.
