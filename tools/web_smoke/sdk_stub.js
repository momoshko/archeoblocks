// Minimal local stand-in for the Yandex Games SDK, used only for automated smoke tests.
(function () {
  const log = (name, detail) => { window.__ya.calls.push(detail === undefined ? name : name + ':' + JSON.stringify(detail)); };
  window.__ya = { calls: [], handlers: {}, data: (location.search.includes('fresh') ? {} : { progress: { save_version: 1, completed_expeditions: { expedition_01: true }, chapter_rewards: {}, coins: 0 } }) };
  const player = {
    isAuthorized: () => false, getUniqueID: () => 'local', getName: () => '', getPhoto: () => '', getPayingStatus: () => '', getSignature: () => '',
    getData: async (keys) => { log('player.getData'); return JSON.parse(JSON.stringify(window.__ya.data)); },
    setData: async (data, flush) => { log('player.setData', data); window.__ya.data = JSON.parse(JSON.stringify(data)); },
    getStats: async () => ({}), setStats: async () => {},
  };
  const ysdk = {
    environment: { i18n: { lang: 'ru', tld: 'ru' }, app: { id: 'local' }, browser: { lang: 'ru' } },
    deviceInfo: { type: 'desktop', isMobile: () => false, isTablet: () => false, isDesktop: () => true, isTV: () => false },
    features: {
      LoadingAPI: { ready: () => log('LoadingAPI.ready') },
      GameplayAPI: { start: () => log('GameplayAPI.start'), stop: () => log('GameplayAPI.stop') },
    },
    adv: {
      showFullscreenAdv: ({ callbacks }) => { log('adv.fullscreen'); setTimeout(() => callbacks.onOpen && callbacks.onOpen(), 50); setTimeout(() => callbacks.onClose && callbacks.onClose(true), 300); },
      showRewardedVideo: ({ callbacks }) => {
        log('adv.rewarded'); setTimeout(() => callbacks.onOpen && callbacks.onOpen(), 50);
        const mode = window.__ya.rewardMode || 'reward';
        setTimeout(() => {
          if (mode === 'reward') callbacks.onRewarded && callbacks.onRewarded();
          if (mode === 'error') { callbacks.onError && callbacks.onError(new Error('mock error')); return; }
          callbacks.onClose && callbacks.onClose(true);
        }, 400);
      },
    },
    getPlayer: async () => { log('getPlayer'); return player; },
    on: (name, cb) => { window.__ya.handlers[name] = cb; },
    off: () => {},
    serverTime: () => Date.now(),
    isAvailableMethod: async () => true,
  };
  window.YaGames = { init: async () => { log('YaGames.init'); return ysdk; } };
})();
