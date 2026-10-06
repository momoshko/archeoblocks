import asyncio, json, sys
from playwright.async_api import async_playwright
CLICK_NEXT = len(sys.argv) > 1
async def drag(page, sx, sy, tx, ty):
    await page.mouse.move(sx, sy); await page.mouse.down()
    for i in range(1, 11):
        await page.mouse.move(sx + (tx - sx) * i / 10, sy + (ty - sy) * i / 10); await page.wait_for_timeout(20)
    await page.mouse.up(); await page.wait_for_timeout(700)
async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
        page = await browser.new_page(viewport={"width": 450, "height": 800})
        console = []
        page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
        page.on("pageerror", lambda e: console.append(f"pageerror: {e}"))
        await page.add_init_script("window.__freshPlayer = true")
        await page.goto("http://localhost:8090/index.html?fresh=1")
        await page.wait_for_function("window.__ya && window.__ya.calls.includes('LoadingAPI.ready')", timeout=90000)
        await page.wait_for_timeout(800)
        await page.mouse.click(225, 436)   # Играть
        await page.wait_for_timeout(2000)
        await page.mouse.click(225, 180)   # Понятно
        await page.wait_for_timeout(600)
        await drag(page, 75, 615, 126, 344)
        await drag(page, 225, 615, 243, 344)
        await drag(page, 375, 615, 321, 344)
        await page.wait_for_timeout(3500)
        await page.screenshot(path="/tmp/shot_victory.png")
        if CLICK_NEXT:
            nx, ny = [int(v) for v in sys.argv[1].split(",")]
            await page.mouse.click(nx, ny)
            await page.wait_for_timeout(2500)
            await page.screenshot(path="/tmp/shot_next.png")
        print("CALLS", json.dumps((await page.evaluate("window.__ya.calls")), ensure_ascii=False)[:600])
        errs = [c for c in console if c.startswith(("error", "pageerror"))]
        print("ERRORS", errs[:10])
        await browser.close()
asyncio.run(main())
