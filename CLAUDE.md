# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Island Conquest is a two-player, hot-seat, turn-based strategy game in Godot 4.7, written in GDScript. Two kingdoms start in opposite corners of a generated hex island and fight over barbarian regions with dice. `README.md` has the rules and controls as the players see them. `docs/adr/` has the reasons behind them; read the relevant record before changing a rule.

## Commands

There is no Godot MCP server here. Use the Godot binary directly. On macOS it is `/Applications/Godot.app/Contents/MacOS/Godot`; elsewhere use `godot`.

```bash
godot --path .                                        # run the game
godot --headless --path . -s tests/run_tests.gd       # rule tests, exits non-zero on failure
godot --path . -s tests/screenshot.gd -- <output dir> # drive the UI in a window, save screenshots
```

## Layout

| Path | Role |
| --- | --- |
| `rules/game_state.gd` | All rules: income, combat, the general, supply, plague, revolt, victory |
| `rules/map_generator.gd` | Island and region generation |
| `rules/region.gd`, `rules/hex.gd` | Region data, hex grid maths (odd-row offset, pointy-top) |
| `scenery.gd` | Cosmetic terrain: heights, mountains, forests, rivers |
| `map_view.gd` | Draws everything on the map, hit-tests clicks |
| `main.gd` | Turn flow, kingdom sidebars, on-map controls, banner, toasts |
| `tests/run_tests.gd` | Headless rule tests and bot-played full games |
| `tests/screenshot.gd` | Windowed UI drive with real input events |

## Conventions

- **Rules stay pure.** Nothing in `rules/` may depend on a scene, a node or drawing. Presentation reads rule state; it never duplicates a rule. See ADR 0002.
- **No comments in code.** Explain reasoning in the commit message or an ADR. The only exception is a one-line note about a trap a reader would fall into.
- **Scripts are loaded with `preload` constants**, not `class_name`, so they work from `-s` scripts without an import pass.
- **Type inference:** `:=` fails to parse when the right-hand side is a Variant (an element of an untyped array, a dictionary lookup, a call on an untyped object). Give the type explicitly in those cases.
- **Randomness is injected.** `GameState.roll_die` and `GameState.roll_chance` are callables; tests replace them with scripted values. Do not call the random number generator directly from a rule.
- **Tests:** the fewest that cover the behaviour that matters. Rules are tested headless on small hand-built maps (`_line_state`). A change to a rule comes with a test that fails without it.
- **Tunable numbers are constants** at the top of `rules/game_state.gd`.

## UI principles

- **Action happens on the map.** Buttons, dice, results, toasts and event notices appear at the region they concern. The sidebars only hold scores and static information. See ADR 0009.
- **Show, do not tell.** Prefer colour, markers, chips and numbers over sentences. One or two words where text is needed.
- **Offer the action, then explain the refusal.** A move or attack that is not allowed is still shown; trying it produces a toast with the reason.
- **Each kingdom has its own sidebar**, Crimson on the left and Azure on the right. Turn controls sit on the side of the kingdom whose turn it is.

## Verifying changes

Run the rule tests, then drive the real UI with `tests/screenshot.gd` and look at the screenshots. Do not hand visual checks to the user.

The screenshot driver pushes real input events into the window. Real mouse movement over that window is delivered too and can disturb hover-dependent steps, so treat a hover result that looks wrong as possibly flaky before treating it as a bug.

## Not built yet

Decided for later, do not build unprompted: a per-turn money system for buildings, buying additional generals, and a computer opponent. Keep turn phases and region data easy to extend for them.
