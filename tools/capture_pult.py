"""Картинка страницы пульта для инструкции.

Страница берётся ровно та, что отдаёт tools/remote/server.py, а вместо живого
кадра симулятора подставляется снимок экрана приложения из UI-тестов.
"""

import base64
import os
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "remote"))
os.environ.setdefault("SIM_UDID", "preview")

import server  # noqa: E402  — нужна только разметка страницы

FRAME = ROOT / "lab1" / "screens" / "iphone-01-home.png"
OUT = ROOT / "docs" / "guide" / "11-pult-app.png"


def main() -> None:
    data = base64.b64encode(FRAME.read_bytes()).decode()
    page_html = server.APP_PAGE.replace(
        "refresh();",
        f"screen.src = 'data:image/png;base64,{data}';",
    )
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_page(viewport={"width": 900, "height": 1000})
        page.set_content(page_html)
        page.wait_for_timeout(800)
        page.screenshot(path=str(OUT))
        browser.close()
    print("снято:", OUT.name)


if __name__ == "__main__":
    main()
