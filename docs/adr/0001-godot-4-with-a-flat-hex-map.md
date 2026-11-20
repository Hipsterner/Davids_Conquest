# 0001. Godot 4 with a flat hex map

Status: accepted

## Context

The game needed a 2D island divided into regions, playable by two people on one screen, without investing in advanced graphics. Isometric 2D was the first idea.

## Decision

Use Godot 4.7 with GDScript. Draw the island as flat, pointy-top hex cells grouped into regions, slightly squashed vertically and given a cliff edge and shadow for depth. Everything is drawn in code with `_draw`; there are no image assets.

## Consequences

- No art pipeline. The whole look is adjustable in code.
- Hit-testing is exact and cheap: the nearest hex centre is the cell under the cursor.
- The map is not truly isometric. Tall decorations (mountains, castles) are drawn as flat glyphs.
