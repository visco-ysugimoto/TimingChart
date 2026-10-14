"""VTV-9000 の画面から、グレー余白に囲まれたカメラ画像だけを切り抜く。

グレーの幅は画面ごとに変わる。上下の余白が無く、画像が縦いっぱいに
埋まっている場合でも、左右のグレー帯から範囲を決める。

使い方:
  python clip_image.py
      常駐する。Ctrl+Alt+Shift+C で画面を切り抜き、クリップボードへ入れる。
  python clip_image.py --once
      今見えている画面を 1 回だけ切り抜く。
  python clip_image.py 画像.png --save 出力.png
      保存済みの画面コピーを切り抜く。

終了は、起動したコンソールを閉じる。
"""

from __future__ import annotations

import argparse
import ctypes
import io
import sys
import time
import winsound
from collections import Counter
from ctypes import wintypes

from PIL import Image, ImageGrab

# 平坦なグレーとみなす許容差。画面の生キャプチャはほぼ一致し、
# 圧縮されたスクリーンショットでは数階調ずれる。
CANVAS_TOLERANCE = 14
MIN_MARGIN = 8
MIN_CONTENT_WIDTH = 80
# 白っぽい別ウィンドウ（ファイル一覧など）を画像と誤認しないため。
MAX_LIGHT_FRACTION = 0.92


def _set_dpi_aware() -> None:
    """座標とキャプチャが拡大表示でずれないようにする。"""
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except Exception:
        try:
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass


def _luminance(rgb: tuple[int, int, int]) -> float:
    return (rgb[0] + rgb[1] + rgb[2]) / 3.0


def _chroma(rgb: tuple[int, int, int]) -> int:
    return max(rgb) - min(rgb)


def detect_canvas_color(image: Image.Image) -> tuple[int, int, int]:
    """左寄りの、長く続く平坦なグレーの代表色を返す。"""
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    buckets: Counter[tuple[int, int, int]] = Counter()

    for y in range(0, height, 2):
        x = 0
        while x < width:
            color = pixels[x, y]
            if _chroma(color) > 8 or not (60 <= _luminance(color) <= 190):
                x += 1
                continue
            start = x
            base = color
            x += 1
            while x < width:
                sample = pixels[x, y]
                if _chroma(sample) > 8:
                    break
                if any(abs(sample[i] - base[i]) > 6 for i in range(3)):
                    break
                x += 1
            length = x - start
            if length >= 24 and start < width * 0.85:
                key = tuple((channel // 4) * 4 for channel in base)
                buckets[key] += length

    if not buckets:
        raise LookupError("グレーの表示領域が見つかりません。")
    color, _ = buckets.most_common(1)[0]
    return color


def _is_canvas(
    color: tuple[int, int, int],
    canvas: tuple[int, int, int],
    tolerance: int,
) -> bool:
    return _chroma(color) <= 10 and all(
        abs(color[i] - canvas[i]) <= tolerance for i in range(3)
    )


def _canvas_runs(
    pixels,
    y: int,
    width: int,
    canvas: tuple[int, int, int],
    tolerance: int,
) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    x = 0
    while x < width:
        if _is_canvas(pixels[x, y], canvas, tolerance):
            start = x
            x += 1
            while x < width and _is_canvas(pixels[x, y], canvas, tolerance):
                x += 1
            if x - start >= MIN_MARGIN:
                runs.append((start, x))
        else:
            x += 1
    return runs


def _looks_like_camera(pixels, y: int, left: int, right: int) -> bool:
    """白や淡い UI の隙間ではなく、カメラ画像の行かを見る。"""
    step = 2
    total = 0
    light = 0
    for x in range(left, right + 1, step):
        total += 1
        if _luminance(pixels[x, y]) > 220:
            light += 1
    if total == 0:
        return False
    return (light / total) < MAX_LIGHT_FRACTION


def _row_spans(
    pixels,
    y: int,
    width: int,
    canvas: tuple[int, int, int],
    tolerance: int,
) -> list[tuple[int, int]]:
    """左右をグレー帯で挟まれた区間を返す。区間は両端を含む。"""
    runs = _canvas_runs(pixels, y, width, canvas, tolerance)
    spans: list[tuple[int, int]] = []
    for index in range(len(runs) - 1):
        left = runs[index][1]
        right = runs[index + 1][0] - 1
        if right - left + 1 < MIN_CONTENT_WIDTH:
            continue
        if _looks_like_camera(pixels, y, left, right):
            spans.append((left, right))
    return spans


def _dominant_value(values: list[int], tolerance: int = 8) -> int:
    rounded = [(value // 4) * 4 for value in values]
    mode, _ = Counter(rounded).most_common(1)[0]
    cluster = [value for value in values if abs(value - mode) <= tolerance]
    cluster.sort()
    return cluster[len(cluster) // 2]


def find_camera_box(image: Image.Image) -> tuple[int, int, int, int]:
    """カメラ画像の (left, top, right, bottom)。right/bottom は含む。"""
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    canvas = detect_canvas_color(rgb)

    hits: list[tuple[int, int, int]] = []
    for y in range(height):
        for left, right in _row_spans(pixels, y, width, canvas, CANVAS_TOLERANCE):
            hits.append((y, left, right))
    if len(hits) < 16:
        raise LookupError("グレーに囲まれた画像が見つかりません。")

    content_left = _dominant_value([left for _, left, _ in hits])
    content_right = _dominant_value([right for _, _, right in hits])
    rows = [
        y
        for y, left, right in hits
        if abs(left - content_left) <= 10 and abs(right - content_right) <= 10
    ]
    if len(rows) < 16:
        raise LookupError("グレーに囲まれた画像が見つかりません。")

    top = min(rows)
    bottom = max(rows)

    def mostly_canvas(y: int) -> bool:
        count = 0
        canvas_count = 0
        for x in range(content_left, content_right + 1, 2):
            count += 1
            if _is_canvas(pixels[x, y], canvas, CANVAS_TOLERANCE):
                canvas_count += 1
        return count > 0 and (canvas_count / count) > 0.85

    while top < bottom and mostly_canvas(top):
        top += 1
    while bottom > top and mostly_canvas(bottom):
        bottom -= 1

    if bottom - top < 16 or content_right - content_left < MIN_CONTENT_WIDTH:
        raise LookupError("切り抜ける画像が小さすぎます。")
    return content_left, top, content_right, bottom


def crop_camera_image(image: Image.Image) -> Image.Image:
    left, top, right, bottom = find_camera_box(image)
    return image.crop((left, top, right + 1, bottom + 1))


def copy_image_to_clipboard(image: Image.Image) -> None:
    """画像をクリップボードへ入れる。成功後のメモリは OS が所有する。"""
    buffer = io.BytesIO()
    image.convert("RGB").save(buffer, "BMP")
    dib = buffer.getvalue()[14:]

    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    if not user32.OpenClipboard(None):
        raise OSError("クリップボードを開けません。")
    handle = None
    transferred = False
    try:
        if not user32.EmptyClipboard():
            raise OSError("クリップボードを空にできません。")
        GMEM_MOVEABLE = 0x0002
        handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(dib))
        if not handle:
            raise OSError("クリップボード用のメモリを確保できません。")
        pointer = kernel32.GlobalLock(handle)
        if not pointer:
            raise OSError("クリップボード用のメモリをロックできません。")
        ctypes.memmove(pointer, dib, len(dib))
        kernel32.GlobalUnlock(handle)
        if not user32.SetClipboardData(8, handle):  # CF_DIB
            raise OSError("クリップボードへ画像を設定できません。")
        transferred = True
    finally:
        user32.CloseClipboard()
        if handle and not transferred:
            kernel32.GlobalFree(handle)


def capture_screen() -> Image.Image:
    return ImageGrab.grab(all_screens=True)


def _beep(success: bool) -> None:
    if success:
        winsound.Beep(880, 70)
    else:
        winsound.Beep(220, 180)


def clip_from_image(image: Image.Image, save_path: str | None, to_clipboard: bool) -> Image.Image:
    cropped = crop_camera_image(image)
    if save_path:
        cropped.save(save_path)
    if to_clipboard:
        copy_image_to_clipboard(cropped)
    return cropped


def run_once(save_path: str | None) -> int:
    try:
        cropped = clip_from_image(capture_screen(), save_path, to_clipboard=True)
    except LookupError as error:
        print(error)
        _beep(False)
        return 1
    print(f"切り抜きました: {cropped.size[0]} x {cropped.size[1]} px（クリップボード）")
    _beep(True)
    return 0


def _parse_hotkey(text: str) -> tuple[int, int]:
    parts = [part.strip().lower() for part in text.split("+") if part.strip()]
    modifiers = 0
    key = None
    mod_map = {
        "ctrl": 0x0002,
        "control": 0x0002,
        "alt": 0x0001,
        "shift": 0x0004,
        "win": 0x0008,
    }
    for part in parts:
        if part in mod_map:
            modifiers |= mod_map[part]
            continue
        if len(part) == 1 and "a" <= part <= "z":
            key = ord(part.upper())
            continue
        if part.startswith("f") and part[1:].isdigit():
            number = int(part[1:])
            if 1 <= number <= 24:
                key = 0x70 + number - 1
                continue
        raise SystemExit(f"ショートカットを解釈できません: {text}")
    if key is None or modifiers == 0:
        raise SystemExit("ショートカットには修飾キーとキーの両方が必要です。例: ctrl+alt+shift+c")
    modifiers |= 0x4000  # MOD_NOREPEAT
    return modifiers, key


def run_hotkey(hotkey: str) -> int:
    modifiers, key = _parse_hotkey(hotkey)
    user32 = ctypes.windll.user32
    hotkey_id = 1
    if not user32.RegisterHotKey(None, hotkey_id, modifiers, key):
        print(f"ショートカット {hotkey} を登録できません。他のソフトが使用中の可能性があります。")
        return 1

    print(f"待機中です。{hotkey} で、いま画面にあるグレー枠内の画像を切り抜きます。")
    print("終了するには、このウィンドウを閉じてください。")
    message = wintypes.MSG()
    try:
        while user32.GetMessageW(ctypes.byref(message), None, 0, 0) != 0:
            if message.message == 0x0312:  # WM_HOTKEY
                try:
                    cropped = clip_from_image(capture_screen(), None, to_clipboard=True)
                    stamp = time.strftime("%H:%M:%S")
                    print(f"[{stamp}] {cropped.size[0]} x {cropped.size[1]} px をクリップボードへ入れました。")
                    _beep(True)
                except LookupError as error:
                    print(f"[{time.strftime('%H:%M:%S')}] {error}")
                    _beep(False)
                except OSError as error:
                    print(f"[{time.strftime('%H:%M:%S')}] {error}")
                    _beep(False)
            user32.TranslateMessage(ctypes.byref(message))
            user32.DispatchMessageW(ctypes.byref(message))
    finally:
        user32.UnregisterHotKey(None, hotkey_id)
    return 0


def main(argv: list[str]) -> int:
    _set_dpi_aware()
    parser = argparse.ArgumentParser(description="グレー枠内のカメラ画像を切り抜く")
    parser.add_argument("image", nargs="?", help="切り抜く画像ファイル。省略時は画面を使う")
    parser.add_argument("--save", help="切り抜いた画像の保存先")
    parser.add_argument("--once", action="store_true", help="画面を 1 回だけ切り抜く")
    parser.add_argument(
        "--hotkey",
        default="ctrl+alt+shift+c",
        help="常駐時のショートカット（既定: ctrl+alt+shift+c）",
    )
    parser.add_argument(
        "--no-clipboard",
        action="store_true",
        help="クリップボードへ入れない（--save と一緒に使う）",
    )
    args = parser.parse_args(argv)

    if args.image:
        with Image.open(args.image) as source:
            cropped = clip_from_image(
                source,
                args.save,
                to_clipboard=not args.no_clipboard,
            )
        print(f"切り抜きました: {cropped.size[0]} x {cropped.size[1]} px")
        return 0
    if args.once:
        return run_once(args.save)
    return run_hotkey(args.hotkey)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
