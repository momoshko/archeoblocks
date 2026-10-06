# Local patches to YandexGamesSDK4Godot

Vendored from https://github.com/ineedmypills/YandexGamesSDK4Godot at commit
5c7b04be7226bab50256831889bd3816143918e9 (MIT). Only runtime files are kept
(no C#, examples, tests, UI helpers, editor plugin). The editor plugin was removed
on purpose: it rewrote every Web export preset to its own template on each editor
start. The autoload `YandexGames` and the `[yandex_games]` settings live in
project.godot; the page template is `web/yandex_shell.html` (a copy of
`templates/yandex_template.html` with page guards and the game's colors).

## 1. Keep JavaScript callbacks alive (`yandex_games.gd`, `call_js_async`)

`JavaScriptBridge.create_callback` objects are released when the GDScript
reference goes away. Ads send `open`, then `rewarded` and `close` later through
the same callback; after `call_js_async` returned, those later events were
dropped, so rewarded and fullscreen ads hung until the 60–75 s timeout and the
reward was never granted. The patch keeps the last 16 callbacks referenced.
Found with a browser smoke test against a local SDK stand-in.

## 2. Ad flows never finished (`modules/ads.gd`, web branch)

`show_interstitial` and `show_rewarded` tracked `is_finished` / `got_reward` /
`was_shown` as local bools changed inside a lambda. GDScript lambdas capture
locals by value, so the outer loop never saw `is_finished = true` and waited
forever (every timeout just looped again). In the web build this froze the
"Дальше" button after a victory and every rewarded Undo/Hint. The flags now
live in one Dictionary (`flow`), which lambdas share by reference.
