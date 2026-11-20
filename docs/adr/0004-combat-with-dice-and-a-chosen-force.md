# 0004. Combat with dice and a chosen force

Status: accepted

## Context

Combat had to be simple to read and give the defender a small edge.

## Decision

A battle is fought in rounds. Each round both sides roll one six-sided die; the lower roll loses a soldier and a tie goes to the defender. The attacker chooses how many soldiers attack, by default all but one. The battle ends when that force is spent or the defenders reach zero. Survivors of the force march in and the rest stay home. A region with no soldiers falls without a roll.

## Consequences

- The attacker wins about 42% of rounds and the defender 58%. A rarer tie (larger dice) and an exact 50/50 (re-rolled ties) were offered and declined.
- A region can be left with zero soldiers. It stays owned but undefended.
- An earlier rule forced one soldier to stay behind; it was replaced by the chosen force.
- A defender that is cut off from its castle loses the tie edge: a tie there costs nobody.
