import asyncio, json
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
        page = await browser.new_page(viewport={"width": 450, "height": 800})
        console = []
        page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
        page.on("pageerror", lambda e: console.append(f"pageerror: {e}"))
        await page.goto("http://localhost:8090/index.html")
        await page.wait_for_function("window.__ya && window.__ya.calls.includes('LoadingAPI.ready')", timeout=90000)
        await page.wait_for_timeout(800)
        await page.mouse.click(225, 436)   # Продолжить
        await page.wait_for_timeout(2000)
        await page.mouse.click(225, 180)   # Начать
        await page.wait_for_timeout(600)
        await page.mouse.click(318, 686)   # Подсказка (free)
        await page.wait_for_timeout(2500)
        await page.mouse.click(318, 686)   # Подсказка (rewarded)
        await page.wait_for_timeout(1500)
        await page.screenshot(path="/tmp/shot_hint.png")
        n0 = len(await page.evaluate("window.__ya.calls"))
        await page.evaluate("window.__ya.rewardMode = 'close'")
        await page.wait_for_timeout(2600)
        await page.mouse.click(318, 686)   # Подсказка (rewarded, closed early)
        await page.wait_for_timeout(900)
        await page.screenshot(path="/tmp/shot_noreward.png")
        await page.wait_for_timeout(1500)
        await page.evaluate("window.__ya.handlers['game_api_pause'] && window.__ya.handlers['game_api_pause']()")
        await page.wait_for_timeout(800)
        await page.screenshot(path="/tmp/shot_pause.png")
        await page.evaluate("window.__ya.handlers['game_api_resume'] && window.__ya.handlers['game_api_resume']()")
        print("CALLS", json.dumps((await page.evaluate("window.__ya.calls"))[6:], ensure_ascii=False))
        print("HANDLERS", await page.evaluate("Object.keys(window.__ya.handlers)"))
        errs = [c for c in console if c.startswith(("error", "pageerror"))]
        print("ERRORS", errs[:10])
        await browser.close()
asyncio.run(main())
