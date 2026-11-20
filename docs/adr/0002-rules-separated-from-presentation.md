# 0002. Rules separated from presentation

Status: accepted

## Context

Rules changed many times during play-testing. They had to be verifiable without opening a window, and the user interface had to be free to change without touching them.

## Decision

All rules live in `rules/` as plain `RefCounted` scripts with no scene, node or drawing dependency. `GameState` owns the state and exposes queries (`can_attack`, `can_move`) and actions (`attack_round`, `move`, `end_turn`). Randomness enters through two injectable callables, `roll_die` and `roll_chance`. `main.gd` and `map_view.gd` only read state and call those actions.

## Consequences

- Rules are tested headless on small hand-built maps with scripted dice.
- Bot-played full games run in the test suite and catch rule changes that stop games from ending.
- The interface has been rebuilt several times without a rule change.
- Presentation must never re-implement a rule; if it needs to know something, `GameState` gets a query.
