# Yandex Games release checklist

- [x] Integrate the Yandex Games SDK.
- [x] Call `LoadingAPI.ready` when loading is complete.
- [x] Use GameplayAPI start/stop at the correct gameplay boundaries.
- [x] Pause audio and gameplay on focus loss and while ads are shown.
- [x] Detect language automatically (`Locale`: Yandex `i18n.lang`, player choice in Settings wins).
- [x] Support guest progress saving.
- [x] Ship Russian and English localization (`translations/en.po`).
- [ ] Draft: add English to the game languages and fill in the English title/description/screenshots (texts ready in `STORE_LISTING.md`).
- [ ] Exported build: switch to English (Settings → Language, or an English Yandex interface) and check every screen.
- [x] Offer rewarded ads only as optional bonuses (extra Undo/Hint after the free ones, button says «реклама»; Restart is always free).
- [x] Show interstitial ads only at logical pauses (only after «Дальше» on victory; skipped for 60 s after a rewarded video).
- [x] Put `index.html` in the export root.
- [x] Keep runtime/export filenames ASCII-only (`tests/filenames_test.gd`).
- [x] Keep the uncompressed package under 100 MB.
- [ ] Support desktop and mobile browsers (manual pass below).
- [x] Keep the experience portrait-first (720×1280 layout; set **portrait** orientation for mobile in the draft).
- [ ] Test browser resizing (engine layouts checked at 720×1280, 390×844, 1280×720; drag the browser window in the exported build).
- [x] Prevent system-page scrolling around the game.
- [x] Support both touch and mouse input (`tests/touch_input_test.gd`; still try a real phone, see below).
- [x] Test web export early, not only at release (2026-10-06: Yandex Release export 74 MB, starts in Chromium at 390×844 and 1280×720, menu → expedition 1 works; the only console errors are the missing `/sdk.js`, served by Yandex itself).

## Before sending to moderation (version 1.0)

- [ ] `CREDITS.md`: write the Suno plan for the music (paid plan only) and the Gemini plan for the art.
- [ ] If lolurio sounds were applied: credit «UI Sound Effects by lolurio (CC BY 4.0)» in the store description.
- [ ] Export **Yandex Release** and pack it with `tools\package_yandex.ps1` (index.html in the zip root), portrait orientation, RU + EN texts from `STORE_LISTING.md`, new screenshots from `build/screens/`.
- [ ] Yandex console → Leaderboards: create a leaderboard with the technical name **`endlessScore`** (type: numeric, sort: higher is better, title «Бесконечные раскопки» / «Endless Dig»). Mark it as the main one if you want it on the game page.
- [ ] Check the «Tiny Pops & Sparkles» sound pack license (line_clear, line_clear_multi, hint, streak) — see CREDITS.md.
- [ ] Play in the draft on a phone: site level → dig → «Очистить находку» → next find; Endless lobby → «Раскоп дня»; volume sliders.

## M3.3 manual pass on the exported build

Export **Yandex Release** (Export With Debug off), run `npx @yandex-games/sdk-dev-proxy -p build/yandex --dev-mode=true`, then:

- [ ] Desktop browser, mouse: play Expedition 1 to victory → «Дальше» (interstitial) → Expedition 2.
- [ ] Drag the browser window narrow/wide and short/tall: nothing is cut off, the board stays centred.
- [ ] Phone (upload the archive to the draft and open the draft link on the phone): the dragged piece is drawn above the finger; two fingers do not break the drag.
- [ ] Phone landscape: the game stays usable (the draft orientation setting is portrait).
- [ ] Settings → Language → English: go through menu, chapters, chapter I–III, collection, settings, tutorial, pause, rescue, victory.
- [ ] Rewarded Undo and Hint: closing the ad early gives nothing; watching it gives the bonus; «Дальше» right after it shows no second ad.
- [ ] Switch to another tab during a level: the pause menu opens, sound stops.
- [ ] Package with `tools\package_yandex.ps1`, check the printed size is under 100 MB.

The Yandex SDK is deliberately not implemented in M0.

## M2.1 rewarded and ad design

- [x] Gameplay uses a provider-independent rewarded action service.
- [x] Reward types reserve Extra Undo, Extra Hint, and future Double Coins.
- [x] Reward value is granted only after `reward_granted` for a unique request id.
- [x] Duplicate callbacks, failures, and unavailable providers grant nothing.
- [x] Local mock provider is guarded by `OS.is_debug_build()` and unavailable in release builds.
- [x] Replace the mock with a real Yandex provider in a future SDK milestone.
- [x] Consider interstitials only at logical pauses, such as between completed expeditions.
- [x] Never interrupt drag/active turns, gate basic Restart, auto-open rewarded content, or immediately stack interstitial after rewarded.

M2.1 does not contain the Yandex SDK or real advertisement calls.
