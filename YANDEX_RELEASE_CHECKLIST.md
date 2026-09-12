# Yandex Games release checklist

- [ ] Integrate the Yandex Games SDK.
- [ ] Call `LoadingAPI.ready` when loading is complete.
- [ ] Use GameplayAPI start/stop at the correct gameplay boundaries.
- [ ] Pause audio and gameplay on focus loss and while ads are shown.
- [ ] Detect language automatically.
- [ ] Support guest progress saving.
- [ ] Ship Russian and English localization.
- [ ] Offer rewarded ads only as optional bonuses.
- [ ] Show interstitial ads only at logical pauses.
- [ ] Put `index.html` in the export root.
- [ ] Keep runtime/export filenames ASCII-only.
- [ ] Keep the uncompressed package under 100 MB.
- [ ] Support desktop and mobile browsers.
- [ ] Keep the experience portrait-first.
- [ ] Test browser resizing.
- [ ] Prevent system-page scrolling around the game.
- [ ] Support both touch and mouse input.
- [ ] Test web export early, not only at release.

The Yandex SDK is deliberately not implemented in M0.

