"""Снимки страниц GitHub для инструкции по запуску.

Запуск:
    python tools/capture_github.py login   — открыть окно браузера для входа
    python tools/capture_github.py shots   — снять страницы

Профиль браузера сохраняется рядом с репозиторием, поэтому вход выполняется
один раз: последующие запуски используют сохранённый сеанс.
"""

import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
PROFILE = ROOT.parent / "_pw-profile"
OUT = ROOT / "docs" / "guide"
REPO = "https://github.com/Sliva-PanDa/RPiPiP-TripWardrobe"

VIEWPORT = {"width": 1440, "height": 900}


def open_context(playwright, headless: bool):
    PROFILE.mkdir(parents=True, exist_ok=True)
    return playwright.chromium.launch_persistent_context(
        user_data_dir=str(PROFILE),
        headless=headless,
        viewport=VIEWPORT,
        locale="ru-RU",
        args=["--disable-blink-features=AutomationControlled"],
    )


def is_signed_in(page) -> bool:
    page.goto(REPO, wait_until="domcontentloaded")
    page.wait_for_timeout(1500)
    return page.locator("img.avatar-user, button[aria-label*='account' i]").count() > 0


def login() -> None:
    """Открывает окно браузера и ждёт, пока пользователь войдёт в GitHub."""
    with sync_playwright() as playwright:
        context = open_context(playwright, headless=False)
        page = context.pages[0] if context.pages else context.new_page()
        page.goto("https://github.com/login", wait_until="domcontentloaded")
        print("Войдите в GitHub в открывшемся окне. Окно закроется само.", flush=True)

        for _ in range(600):           # до 10 минут
            time.sleep(1)
            if page.url.startswith("https://github.com/") and "login" not in page.url:
                page.goto(REPO, wait_until="domcontentloaded")
                page.wait_for_timeout(1500)
                if is_signed_in(page):
                    print("Вход выполнен.", flush=True)
                    break
        context.close()


def shot(page, name: str, *, full: bool = False, height: int | None = None) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.png"
    if height:
        page.screenshot(path=str(path),
                        clip={"x": 0, "y": 0, "width": VIEWPORT["width"], "height": height})
    else:
        page.screenshot(path=str(path), full_page=full)
    print(f"снято: {path.name}", flush=True)


def shots() -> None:
    with sync_playwright() as playwright:
        context = open_context(playwright, headless=True)
        page = context.pages[0] if context.pages else context.new_page()
        page.set_default_timeout(30000)

        signed = is_signed_in(page)
        print("вход в аккаунт:", "да" if signed else "нет", flush=True)

        # 1. Главная страница репозитория.
        page.goto(REPO, wait_until="domcontentloaded")
        page.wait_for_timeout(2500)
        shot(page, "01-repo", height=760)

        # 2. Вкладка Actions.
        page.goto(f"{REPO}/actions", wait_until="domcontentloaded")
        page.wait_for_timeout(3000)
        shot(page, "02-actions", height=760)

        # 3. Страница сценария записи видео.
        page.goto(f"{REPO}/actions/workflows/demo-video.yml", wait_until="domcontentloaded")
        page.wait_for_timeout(3000)
        shot(page, "03-workflow", height=760)

        # 4. Раскрытое окно «Run workflow» (видно только владельцу репозитория).
        if signed:
            try:
                button = page.get_by_role("button", name="Run workflow").first
                button.click(timeout=8000)
                page.wait_for_timeout(2000)
                shot(page, "04-run-dialog", height=860)
            except Exception as error:
                print("не удалось раскрыть Run workflow:", error, flush=True)

        # 5. Страница последнего запуска со списком шагов.
        page.goto(f"{REPO}/actions/workflows/demo-video.yml", wait_until="domcontentloaded")
        page.wait_for_timeout(2500)
        link = page.locator("a[href*='/actions/runs/']").first
        if link.count():
            link.click()
            page.wait_for_timeout(4000)
            shot(page, "05-run-page", height=860)

            # 6. Список шагов внутри задания.
            job = page.locator("a[href*='/job/']").first
            if job.count():
                job.click()
                page.wait_for_timeout(5000)
                shot(page, "06-run-steps", height=900)

        context.close()


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "shots"
    if mode == "login":
        login()
    else:
        shots()
