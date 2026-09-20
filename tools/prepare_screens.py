"""Подготовка снимков экрана для отчётов.

Скрипт берёт артефакт GitHub Actions (каталог со снимками, снятыми
UI-тестами), убирает из имён служебные суффиксы xcparse и раскладывает
файлы по каталогам лабораторных работ.

Запуск:
    python tools/prepare_screens.py <каталог-артефакта> <lab1|lab2|lab3|lab4>
"""

import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Какие снимки относятся к какой лабораторной работе.
LAB_SCREENS = {
    "lab1": ["01-home", "02-look-expanded", "03-search", "04-item",
             "05-filter-laundry", "06-season", "07-look"],
    "lab2": ["08-trip-list", "09-trip-detail", "10-autopack",
             "11-trip-packed", "12-limit-switch"],
    "lab3": ["13-settings", "14-settings-storage",
             "15-appearance-dark", "16-wardrobe-dark"],
    "lab4": ["17-sync", "18-export", "19-share", "20-offline"],
}

# iphone-01-home_0_2733F634-....png  ->  iphone-01-home
NAME_RE = re.compile(r"^(iphone|ipad)-([0-9]{2}-[a-z-]+)_\d+_[0-9A-F-]+\.png$", re.I)


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 1

    source = Path(sys.argv[1])
    lab = sys.argv[2]
    if lab not in LAB_SCREENS:
        print(f"Неизвестная лабораторная работа: {lab}")
        return 1

    target = ROOT / lab / "screens"
    target.mkdir(parents=True, exist_ok=True)

    wanted = set(LAB_SCREENS[lab])
    copied = 0
    for path in sorted(source.rglob("*.png")):
        match = NAME_RE.match(path.name)
        if not match:
            continue
        device, shot = match.group(1).lower(), match.group(2).lower()
        if shot not in wanted:
            continue
        shutil.copyfile(path, target / f"{device}-{shot}.png")
        copied += 1

    print(f"{lab}: скопировано снимков — {copied}")
    missing = sorted(
        f"{device}-{shot}"
        for shot in wanted
        for device in ("iphone", "ipad")
        if not (target / f"{device}-{shot}.png").exists()
    )
    if missing:
        print("Отсутствуют:", ", ".join(missing))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
