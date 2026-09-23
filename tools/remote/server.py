#!/usr/bin/env python3
"""Веб-пульт для симулятора iOS, запущенного на раннере GitHub Actions.

Сервер отдаёт страницу с изображением экрана симулятора и передаёт обратно
нажатия мыши и клавиатуры. Снимки экрана снимаются командой
``xcrun simctl io <udid> screenshot``, события ввода отправляются утилитой
``idb ui`` (tap, swipe, text, key, button).

Переменные окружения:
    SIM_UDID          — идентификатор загруженного симулятора (обязательно);
    REMOTE_PASSWORD   — пароль страницы;
    BUNDLE_ID         — идентификатор приложения для перезапуска;
    PORT              — порт (по умолчанию 8080).
"""

from __future__ import annotations

import http.cookies
import json
import os
import secrets
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote_plus

UDID = os.environ["SIM_UDID"]
PASSWORD = os.environ.get("REMOTE_PASSWORD", "demo")
BUNDLE_ID = os.environ.get("BUNDLE_ID", "by.gstu.itp41.TripWardrobe")
PORT = int(os.environ.get("PORT", "8080"))

# HID-коды клавиш для команды «idb ui key».
KEY_BACKSPACE = 42
KEY_RETURN = 40
KEY_V = 25

_frame: bytes = b""
_frame_lock = threading.Lock()
_sessions: set[str] = set()

# Размер экрана в точках — в них измеряются координаты для idb.
_point_size = (393.0, 852.0)


# --------------------------------------------------------------------------- #
# Работа с симулятором
# --------------------------------------------------------------------------- #

def _run(command: list[str], timeout: float = 25) -> subprocess.CompletedProcess:
    return subprocess.run(command, capture_output=True, timeout=timeout)


def detect_point_size() -> tuple[float, float]:
    """Размер экрана в точках: пиксели снимка, делённые на масштаб."""
    try:
        result = _run(["idb", "describe", "--udid", UDID, "--json"])
        payload = json.loads(result.stdout.decode() or "{}")
        screen = payload.get("screen_dimensions") or {}
        width, height = float(screen["width"]), float(screen["height"])
        density = float(screen.get("density") or 1.0) or 1.0
        return width / density, height / density
    except Exception as error:
        print("Не удалось определить размер экрана:", error, flush=True)
        return _point_size


def grab_loop() -> None:
    """Фоновый поток: раз в полсекунды снимает экран симулятора.

    Снимок пишется во временный файл, а не в стандартный вывод: не все
    версии simctl умеют отдавать PNG в поток.
    """
    global _frame
    path = os.path.join(tempfile.gettempdir(), "tripwardrobe-frame.png")
    while True:
        try:
            result = _run(
                ["xcrun", "simctl", "io", UDID, "screenshot", "--type=png", path],
                timeout=15,
            )
            if result.returncode == 0 and os.path.exists(path):
                with open(path, "rb") as handle:
                    data = handle.read()
                if data:
                    with _frame_lock:
                        _frame = data
            elif result.returncode != 0:
                print("simctl screenshot:", result.stderr.decode()[:200], flush=True)
        except Exception as error:
            print("Сбой снятия экрана:", error, flush=True)
        time.sleep(0.5)


def idb(*arguments: str) -> None:
    """Команда «idb ui <действие> --udid <udid> <аргументы>»."""
    action, rest = arguments[0], arguments[1:]
    try:
        result = _run(["idb", "ui", action, "--udid", UDID, *rest])
        if result.returncode != 0:
            print("idb ui", action, "->", result.stderr.decode()[:200], flush=True)
    except Exception as error:
        print("Сбой idb:", error, flush=True)


def type_text(text: str) -> None:
    """Ввод текста в поле симулятора.

    «idb ui text» печатает, нажимая клавиши американской раскладки, поэтому
    справляется только с латиницей. Остальные символы (кириллица и т. п.)
    кладутся в буфер обмена симулятора и вставляются сочетанием Cmd+V.
    """
    if text.isascii():
        idb("text", text)
        return
    try:
        subprocess.run(["xcrun", "simctl", "pbcopy", UDID],
                       input=text.encode("utf-8"), capture_output=True, timeout=10)
        idb("key", str(KEY_V), "--command")
    except Exception as error:
        print("Сбой вставки текста:", error, flush=True)


def to_points(x: float, y: float) -> tuple[int, int]:
    """Из долей ширины и высоты экрана — в целые точки.

    idb 1.6 принимает только целые координаты: дробные значения вроде
    «201.3 437.0» он отвергает как неразобранный маркер.
    """
    width, height = _point_size
    px = round(max(0.0, min(1.0, x)) * width)
    py = round(max(0.0, min(1.0, y)) * height)
    return min(px, int(width) - 1), min(py, int(height) - 1)


# --------------------------------------------------------------------------- #
# Страницы
# --------------------------------------------------------------------------- #

LOGIN_PAGE = """<!doctype html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Вход</title><style>
:root{color-scheme:light dark}
body{font:16px/1.5 -apple-system,"Segoe UI",system-ui,sans-serif;
 display:grid;place-items:center;min-height:100vh;margin:0}
form{display:grid;gap:.8rem;width:min(22rem,90vw)}
input,button{font:inherit;padding:.7rem .9rem;border-radius:.6rem;
 border:1px solid rgba(127,127,127,.5)}
button{background:#2f6fed;color:#fff;border:0;cursor:pointer}
p{color:#c00;margin:0}
</style></head><body>
<form method="post" action="/login">
  <h1 style="font-size:1.2rem;margin:0">Приложение «Гардероб»</h1>
  <input type="password" name="password" placeholder="Пароль" autofocus>
  <button type="submit">Войти</button>
  __ERROR__
</form></body></html>"""

APP_PAGE = """<!doctype html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Гардероб — симулятор</title><style>
:root{color-scheme:dark}
body{margin:0;background:#101014;color:#eee;font:15px/1.4 -apple-system,
 "Segoe UI",system-ui,sans-serif;display:grid;place-items:center;
 min-height:100vh;gap:.8rem;padding:1rem;box-sizing:border-box}
#screen{max-height:78vh;border-radius:1.6rem;border:2px solid #333;
 background:#000;touch-action:none;cursor:pointer;display:block;
 user-select:none;-webkit-user-select:none;-webkit-user-drag:none}
#bar{display:flex;gap:.5rem;flex-wrap:wrap;justify-content:center}
button{font:inherit;padding:.5rem .9rem;border-radius:.6rem;border:0;
 background:#2a2a32;color:#eee;cursor:pointer}
button:hover{background:#3a3a45}
#hint{opacity:.6;font-size:.85rem;text-align:center;max-width:34rem}
</style></head><body>
<img id="screen" alt="Экран симулятора" draggable="false">
<div id="bar">
  <button onclick="scrollScreen(-1)">▲ Вверх</button>
  <button onclick="scrollScreen(1)">▼ Вниз</button>
  <button onclick="key('backspace')">⌫ Стереть</button>
  <button onclick="key('return')">Enter</button>
  <button onclick="post('/home')">Домой</button>
  <button onclick="post('/relaunch')">Перезапустить приложение</button>
</div>
<p id="hint">Щёлкайте мышью как пальцем. Прокрутка: колёсико мыши,
кнопки «Вверх» и «Вниз» или перетаскивание.
Чтобы ввести текст, нажмите на поле в приложении и печатайте на клавиатуре.
Картинка обновляется с задержкой около секунды.</p>
<script>
const screen = document.getElementById('screen');

async function refresh() {
  try {
    const response = await fetch('/frame.png?' + Date.now(), {cache: 'no-store'});
    if (response.ok) {
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const previous = screen.src;
      screen.src = url;
      if (previous.startsWith('blob:')) URL.revokeObjectURL(previous);
    }
  } catch (error) { /* сеанс мог завершиться */ }
  setTimeout(refresh, 700);
}
refresh();

function post(path, body) {
  return fetch(path, {method: 'POST', headers: {'Content-Type': 'application/json'},
                      body: JSON.stringify(body || {})});
}
function key(name) { post('/key', {key: name}); }

function position(event) {
  const box = screen.getBoundingClientRect();
  return {x: (event.clientX - box.left) / box.width,
          y: (event.clientY - box.top) / box.height};
}

// Браузер по умолчанию «перетаскивает» картинку, и тогда отпускание мыши
// до страницы не доходит — свайп не отправляется. Поэтому своё перетаскивание
// браузеру запрещаем, а указатель захватываем до отпускания.
screen.addEventListener('dragstart', event => event.preventDefault());

let start = null;
screen.addEventListener('pointerdown', event => {
  event.preventDefault();
  start = position(event);
  try { screen.setPointerCapture(event.pointerId); } catch (error) { /* не критично */ }
});
screen.addEventListener('pointerup', event => {
  if (!start) return;
  const end = position(event);
  const distance = Math.hypot(end.x - start.x, end.y - start.y);
  if (distance < 0.02) post('/tap', end);
  else post('/swipe', {x1: start.x, y1: start.y, x2: end.x, y2: end.y});
  start = null;
  try { screen.releasePointerCapture(event.pointerId); } catch (error) { /* не критично */ }
});
screen.addEventListener('pointercancel', () => { start = null; });

// Прокрутка колёсиком мыши и кнопками: один шаг — треть экрана.
function scrollScreen(direction, x = 0.5) {
  const from = direction > 0 ? 0.70 : 0.35;
  const to = direction > 0 ? 0.35 : 0.70;
  post('/swipe', {x1: x, y1: from, x2: x, y2: to});
}

let wheelPending = 0;
screen.addEventListener('wheel', event => {
  event.preventDefault();
  if (wheelPending) return;
  const direction = event.deltaY > 0 ? 1 : -1;
  const point = position(event);
  wheelPending = setTimeout(() => { wheelPending = 0; }, 450);
  scrollScreen(direction, point.x);
}, {passive: false});

document.addEventListener('keydown', event => {
  if (event.metaKey || event.ctrlKey || event.altKey) return;
  if (event.key === 'Backspace') { event.preventDefault(); key('backspace'); }
  else if (event.key === 'Enter') { event.preventDefault(); key('return'); }
  else if (event.key.length === 1) { event.preventDefault(); post('/text', {text: event.key}); }
});
</script></body></html>"""


# --------------------------------------------------------------------------- #
# HTTP-обработчик
# --------------------------------------------------------------------------- #

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):  # тише в журнале раннера
        pass

    # -- вспомогательное -------------------------------------------------- #

    def _authorized(self) -> bool:
        raw = self.headers.get("Cookie")
        if not raw:
            return False
        cookie = http.cookies.SimpleCookie(raw)
        token = cookie.get("sid")
        return bool(token and token.value in _sessions)

    def _send(self, status: int, body: bytes, content_type: str, headers=None) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def _html(self, page: str, status: int = 200, headers=None) -> None:
        self._send(status, page.encode("utf-8"), "text/html; charset=utf-8", headers)

    def _json_body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception:
            return {}

    # -- маршруты --------------------------------------------------------- #

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]

        if path == "/frame.png":
            if not self._authorized():
                return self._send(403, b"", "text/plain")
            with _frame_lock:
                data = _frame
            return self._send(200, data, "image/png")

        if path != "/":
            return self._send(404, b"", "text/plain")

        if self._authorized():
            return self._html(APP_PAGE)
        return self._html(LOGIN_PAGE.replace("__ERROR__", ""))

    def do_POST(self) -> None:
        path = self.path.split("?", 1)[0]

        if path == "/login":
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length).decode("utf-8")
            entered = ""
            for pair in raw.split("&"):
                name, _, value = pair.partition("=")
                if name == "password":
                    entered = unquote_plus(value)
            if entered != PASSWORD:
                return self._html(
                    LOGIN_PAGE.replace("__ERROR__", "<p>Неверный пароль</p>"), status=401)
            token = secrets.token_urlsafe(24)
            _sessions.add(token)
            return self._html(
                APP_PAGE,
                headers={"Set-Cookie": f"sid={token}; Path=/; HttpOnly; SameSite=Lax"})

        if not self._authorized():
            return self._send(403, b"", "text/plain")

        payload = self._json_body()

        if path == "/tap":
            x, y = to_points(float(payload.get("x", 0)), float(payload.get("y", 0)))
            idb("tap", str(x), str(y))
        elif path == "/swipe":
            x1, y1 = to_points(float(payload.get("x1", 0)), float(payload.get("y1", 0)))
            x2, y2 = to_points(float(payload.get("x2", 0)), float(payload.get("y2", 0)))
            idb("swipe", str(x1), str(y1), str(x2), str(y2), "--duration", "0.25")
        elif path == "/text":
            text = str(payload.get("text", ""))[:80]
            if text:
                type_text(text)
        elif path == "/key":
            name = str(payload.get("key", ""))
            code = {"backspace": KEY_BACKSPACE, "return": KEY_RETURN}.get(name)
            if code:
                idb("key", str(code))
        elif path == "/home":
            idb("button", "HOME")
        elif path == "/relaunch":
            _run(["xcrun", "simctl", "terminate", UDID, BUNDLE_ID])
            _run(["xcrun", "simctl", "launch", UDID, BUNDLE_ID])
        else:
            return self._send(404, b"", "text/plain")

        return self._send(200, b"{}", "application/json")


def main() -> None:
    global _point_size
    _point_size = detect_point_size()
    print(f"Размер экрана: {_point_size[0]:.0f}x{_point_size[1]:.0f} точек", flush=True)

    threading.Thread(target=grab_loop, daemon=True).start()

    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Пульт слушает порт {PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
