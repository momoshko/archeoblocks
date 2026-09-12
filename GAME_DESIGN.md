# Archeoblocks — locked V1 game design

## Core rules

- Board: 8×8.
- Tray: 3 block pieces.
- Placement: a piece must fit entirely in empty cells.
- A full row or column clears the placed blocks in that line.
- Each cleared line removes one soil layer from every crossed cell.
- If a row and column clear simultaneously, their intersection receives one excavation from each line.
- Normal soil depth is 1; strong soil depth is 2.
- Each expedition contains one main collectible artifact split into 2–3 buried fragments.
- Fragments are partially hinted beneath soil.
- Fully excavating every fragment wins the expedition.
- The player loses when none of the remaining tray pieces can be legally placed.
- V1 contains 12 expeditions.
- The first tutorial expeditions use scripted piece sequences.
- Later expeditions use seeded weighted piece generation.
- V1 has no player rotation button. Rotated shapes are separate piece definitions.
- Block colors are cosmetic and are not matching mechanics.
- Score and move count are feedback/statistics, not the primary victory requirement.

## Out of scope before first publication

- City building
- Equipment
- Pets
- Currencies
- Shop
- Battle pass
- Daily reward
- Account profile
- Online leaderboard
- Procedural expeditions
- Runtime level generator
- Multiple visual biomes
- Player-controlled piece rotation

## M1 implementation details

- M1 uses three deterministic piece sets in a loop:
  1. small L, small T, horizontal line 3;
  2. square 2×2, vertical domino, horizontal line 3;
  3. single, horizontal domino, vertical line 3.
- A piece is dragged from any available tray slot and snaps by an anchor cell near the center of its definition.
- Mouse drag uses an 8 px visual lift by default.
- Touch drag uses an 82 px visual lift by default so the finger does not cover the preview.
- Mouse and touch lift values are presentation settings on the GameSession node.
- Green-tinted target cells represent a legal placement; red-tinted cells and drag preview represent an illegal placement.
- A used slot stays empty until all three pieces have been placed, then the next deterministic set appears.
- Every full row and column found after one placement clears in the same action.
- M1 intentionally has no fairness generator, score system, soil, excavation, or artifact gameplay.
