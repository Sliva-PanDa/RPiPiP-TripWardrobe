"""Снимки страниц GitHub для инструкции по живому запуску, с красными рамками.

Рамка рисуется вокруг элемента, на который нужно нажать: его положение
берётся из разметки страницы, а не подбирается на глаз.
"""

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "guide"
REPO = "https://github.com/Sliva-PanDa/RPiPiP-TripWardrobe"
VIEWPORT = {"width": 1440, "height": 860}
RED = (220, 30, 30)


def frame(path: Path, boxes, pad: int = 6, width: int = 4) -> None:
    image = Image.open(path).convert("RGB")
    draw = ImageDraw.Draw(image)
    for box in boxes:
        if not box:
            continue
        x, y, w, h = box["x"], box["y"], box["width"], box["height"]
        draw.rectangle([x - pad, y - pad, x + w + pad, y + h + pad], outline=RED, width=width)
    image.save(path)


def box_of(page, locator):
    try:
        element = locator.first
        element.wait_for(timeout=8000)
        return element.bounding_box()
    except Exception as error:
        print("  элемент не найден:", error.__class__.__name__)
        return None


def latest_live_run() -> str:
    gh = r"C:\Program Files\GitHub CLI\gh.exe"
    result = subprocess.run(
        [gh, "run", "list", "--repo", "Sliva-PanDa/RPiPiP-TripWardrobe",
         "--workflow", "live-demo.yml", "--limit", "1", "--json", "databaseId",
         "--jq", ".[0].databaseId"],
        capture_output=True, text=True, check=True)
    return result.stdout.strip()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    run_id = latest_live_run()

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_page(viewport=VIEWPORT, locale="ru-RU")
        page.set_default_timeout(30000)

        # Шаг 1. Главная страница репозитория — вкладка Actions.
        page.goto(REPO, wait_until="domcontentloaded")
        page.wait_for_timeout(2500)
        path = OUT / "20-repo-actions-tab.png"
        page.screenshot(path=str(path), clip={"x": 0, "y": 0, "width": 1440, "height": 520})
        frame(path, [box_of(page, page.locator("#actions-tab"))])
        print("снято:", path.name)

        # Шаг 2. Слева — сценарий «Запустить приложение в браузере».
        page.goto(f"{REPO}/actions", wait_until="domcontentloaded")
        page.wait_for_timeout(3000)
        path = OUT / "21-actions-sidebar.png"
        page.screenshot(path=str(path), clip={"x": 0, "y": 0, "width": 1440, "height": 620})
        frame(path, [box_of(page, page.get_by_role("link", name="Запустить приложение в браузере"))])
        print("снято:", path.name)

        # Шаг 3. Страница сценария: здесь у владельца справа кнопка Run workflow.
        page.goto(f"{REPO}/actions/workflows/live-demo.yml", wait_until="domcontentloaded")
        page.wait_for_timeout(3000)
        path = OUT / "22-live-workflow.png"
        page.screenshot(path=str(path), clip={"x": 0, "y": 0, "width": 1440, "height": 560})
        print("снято:", path.name)

        # Шаг 5. Страница запуска: слева задание remote.
        page.goto(f"{REPO}/actions/runs/{run_id}", wait_until="domcontentloaded")
        page.wait_for_timeout(4000)
        path = OUT / "23-live-run.png"
        page.screenshot(path=str(path), clip={"x": 0, "y": 0, "width": 1440, "height": 700})
        frame(path, [box_of(page, page.get_by_role("link", name="remote"))])
        print("снято:", path.name)

        browser.close()


if __name__ == "__main__":
    main()
