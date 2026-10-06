# Music

The game picks tracks up by file name (no code changes). How to make them in
Suno, the prompts and how many are needed: `MUSIC_SUNO_RU.md` in the project root.
Raw downloads go to `audio_review/music_raw/`, then `python tools/prepare_music.py`
puts the game-ready `.ogg` files here.

| File | Plays |
| --- | --- |
| `menu.ogg` | Main menu, chapters, collection, settings |
| `gameplay_ancient_courtyard.ogg` | Chapter I |
| `gameplay_ruined_shrine.ogg` | Chapter II |
| `gameplay_overgrown_catacombs.ogg` | Chapter III |
| `gameplay_endless.ogg` | Endless Excavation |
| `restoration.ogg` | Restoration screen (falls back to `menu`) |
| `gameplay.ogg` | Fallback for a chapter (or endless) without its own track |

`.ogg` is best for the web build (small); `.mp3` and `.wav` also work.
Tracks loop automatically and cross-fade when the screen changes.
Record every track with its source and license in `CREDITS.md`
(Suno: paid plan only, the free plan forbids commercial use).
