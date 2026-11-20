# 0008. A world turn for events

Status: accepted

## Context

Random events were wanted between turns, starting with a plague, with more to come.

## Decision

After each player's turn the island takes a turn of its own, run by `_run_world_turn` in `GameState`. It checks revolts and rolls for the plague: each region rolls two dice and on a double one loses half its soldiers, rounded down, with a lone soldier always surviving. What happened is recorded in `GameState.events` until the next world turn.

## Consequences

- About one outbreak happens somewhere on the island every two world turns.
- The interface reads `events` to mark struck regions and to summarise the turn in the banner.
- A new event is a new branch in the world turn plus a new event kind; nothing else needs to know.
