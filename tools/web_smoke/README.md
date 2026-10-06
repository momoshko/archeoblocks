# Web smoke tests (automated browser check of the Yandex build)

Used by the assistant in its cloud workspace; optional for manual use.

1. Export "Yandex Release" to `build/yandex/`.
2. Copy the build to a folder, add `sdk_stub.js` there as `sdk.js`
   (a local stand-in for the Yandex SDK that records every call in `window.__ya.calls`).
3. Serve it: `python -m http.server 8090`.
4. Run with Python Playwright: `python ads_and_pause.py`,
   `python tutorial_victory_next.py 295,520` (clicks "Дальше" at x,y for a 450×800 page).

Checks: boot (init → player data merge → LoadingAPI.ready), GameplayAPI start/stop,
rewarded hint granted / closed without reward, platform pause opens the pause menu,
tutorial level → victory → cloud save → interstitial → next expedition, no console errors.
