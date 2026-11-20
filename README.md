# Island Conquest

Two-player, hot-seat, turn-based strategy on a generated island. Godot 4.7.

## Run

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Rules

- Each kingdom starts with a castle in its own corner of the island. Every other region belongs to barbarians.
- Each kingdom starts with 2 soldiers in its castle. From round 2 the castle gains 1 soldier every round, whatever else happens. New soldiers arrive every third round (rounds 3, 6, 9, ...). In those rounds every region you own gains 2 soldiers at the start of your turn. Every round each barbarian region has a 75% chance of gaining a soldier, up to 5.
- A region you have just conquered needs to recover: it misses the next arrival of new soldiers.
- A newly conquered region is unsecure for two rounds. If it is left without soldiers in that time it may revolt after any player's turn (a die roll of 1 or 2) and go back to the barbarians. One soldier keeps it safe.
- A region with no chain of your regions back to your castle is cut off: it gains 1 soldier and loses the defender's edge.
- Only the region holding your general can attack. The general follows a conquest, can march to one neighbouring region of yours per turn, and escapes to the nearest region you still own if their region falls.
- After each player's turn the island takes a turn of its own. Every region rolls two dice, and on a double one the plague breaks out there and kills half its soldiers (a lone soldier always survives).
- A battle is fought round by round: both sides roll a die, the lower roll loses a soldier, ties go to the defender. You choose how many soldiers attack, by default all but one. The battle ends when that force is spent or the defenders are gone, and the surviving attackers march in while the rest stay home. A region with no soldiers falls without a fight.
- You may attack and move soldiers between neighbouring regions of yours as often as you like before ending the turn.
- Take the enemy castle to win.

## Controls

- Left-click a region of yours to select it. Click it again, or the sea, to deselect.
- With a region selected, left-click a neighbouring region of yours to send one soldier there (Shift: all but one), or a neighbouring enemy to attack. Right-click and Ctrl-click also move.
- Select a region next to your general and press "Move general here" to move the general.

## Tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run_tests.gd
```

`tests/screenshot.gd` plays a few turns in a window and saves screenshots to the folder given after `--`.

## Layout

- `rules/` holds the game rules with no scene dependencies: map generation, income, combat, supply lines.
- `map_view.gd` draws the island and turns clicks into regions; `main.gd` is the turn flow and side panel.
