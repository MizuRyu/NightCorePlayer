# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""App Store 用の説明画像を合成する (#73)。

生スクショ (capture_app_store_screenshots.sh の出力) に
グラデーション背景 + キャッチコピー + 角丸フレームを重ね、
App Store の要求解像度そのままで書き出す。

使い方:
  uv run scripts/compose_store_screenshots.py \
      --input build/app-store-screenshots/ja --output build/app-store-marketing/ja
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# 画面サイズは入力スクショに合わせる (iPhone 16 Pro Max = 1320x2868)
# ヒラギノは欧文字形が本文向けで見出しに弱い。英語は SF Pro を使う。
# SFNS.ttf は可変フォントで、ウェイトを指定しないと Regular になり見出しが痩せる。
# (path, variation) の variation は可変フォントのときだけ使う。
FONTS = {
    "ja": (
        ("/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", None),
        ("/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc", None),
    ),
    "en-US": (
        ("/System/Library/Fonts/SFNS.ttf", "Bold"),
        ("/System/Library/Fonts/SFNS.ttf", "Regular"),
    ),
}


def load_font(spec: tuple[str, str | None], size: int) -> ImageFont.FreeTypeFont:
    path, variation = spec
    font = ImageFont.truetype(path, size)
    if variation:
        font.set_variation_by_name(variation)
    return font

# 訴求順とコピー (#73)。キーは生スクショのシーン名
# 訴求順は「何ができるか → どう探すか → どこまで細かく操れるか」。
# 1枚目で用途を伝え、2枚目以降で導線と作り込みを見せる。
# 背景色はシーンごとに変え、一覧に並んだときに区別できるようにする。
BACKGROUNDS = {
    "player": ((24, 16, 48), (88, 40, 128)),
    "search": ((16, 32, 56), (32, 88, 136)),
    "playlist": ((40, 20, 40), (128, 48, 88)),
    "queue": ((20, 36, 32), (32, 104, 88)),
}

COPY_BY_LANG = {
    "ja": {
        "player": {
            "headline": "Apple Music の曲を、\nナイトコアに。",
            "sub": "好きな曲をそのまま倍速再生",
        },
        "search": {
            "headline": "検索して、\nすぐ倍速。",
            "sub": "Apple Music のカタログをそのまま検索",
        },
        "playlist": {
            "headline": "プレイリストごと、\n自分のテンポで。",
            "sub": "ライブラリのプレイリストを丸ごと倍速再生",
        },
        "queue": {
            "headline": "0.5x 〜 3.0x、\n0.01 刻み。",
            "sub": "キューも速度も思いのまま",
        },
    },
    "en-US": {
        "player": {
            "headline": "Turn Apple Music\ninto nightcore.",
            "sub": "Speed up any song, right where it plays",
        },
        "search": {
            "headline": "Search it.\nSpeed it up.",
            "sub": "The full Apple Music catalog, sped up",
        },
        "playlist": {
            "headline": "Whole playlists,\nat your tempo.",
            "sub": "Play your library faster, end to end",
        },
        "queue": {
            "headline": "0.5x to 3.0x,\nin 0.01 steps.",
            "sub": "Fine-tune the queue and the speed",
        },
    },
}

SCENES = list(BACKGROUNDS)

COPY_AREA_RATIO = 0.24  # 上部のコピー領域
SCREENSHOT_SCALE = 0.82
CORNER_RADIUS = 110


def vertical_gradient(size: tuple[int, int], top: tuple, bottom: tuple) -> Image.Image:
    base = Image.new("RGB", (1, size[1]))
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        base.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return base.resize(size)


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(shot_path: Path, scene: str, out_dir: Path, lang: str) -> Path:
    spec = COPY_BY_LANG[lang][scene]
    headline_font_path, sub_font_path = FONTS[lang]
    shot = Image.open(shot_path).convert("RGB")
    width, height = shot.size

    canvas = vertical_gradient((width, height), *BACKGROUNDS[scene]).convert("RGBA")

    # 端末スクショ: 角丸 + 影で下部に配置
    scaled = shot.resize((int(width * SCREENSHOT_SCALE), int(height * SCREENSHOT_SCALE)))
    framed = rounded(scaled, CORNER_RADIUS)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sx = (width - framed.width) // 2
    sy = int(height * COPY_AREA_RATIO)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(sx - 8, sy + 24), (sx + framed.width + 8, sy + framed.height + 24)],
        radius=CORNER_RADIUS, fill=(0, 0, 0, 140),
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))
    canvas.alpha_composite(framed, (sx, sy))

    # コピー
    draw = ImageDraw.Draw(canvas)
    headline_font = load_font(headline_font_path, int(width * 0.072))
    sub_font = load_font(sub_font_path, int(width * 0.034))
    y = int(height * 0.045)
    for line in spec["headline"].split("\n"):
        bbox = draw.textbbox((0, 0), line, font=headline_font)
        draw.text(((width - bbox[2]) / 2, y), line, font=headline_font, fill=(255, 255, 255))
        y += int((bbox[3] - bbox[1]) * 1.45)
    bbox = draw.textbbox((0, 0), spec["sub"], font=sub_font)
    draw.text(((width - bbox[2]) / 2, y + int(height * 0.012)), spec["sub"],
              font=sub_font, fill=(255, 255, 255, 220))

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{scene}.png"
    canvas.convert("RGB").save(out_path, "PNG")
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--lang", choices=sorted(COPY_BY_LANG), default="ja")
    args = parser.parse_args()

    results = {}
    for scene in SCENES:
        matches = sorted(args.input.rglob(f"*{scene}*.png"))
        if not matches:
            print(f"skip: {scene} (raw screenshot not found)")
            continue
        out = compose(matches[0], scene, args.output, args.lang)
        results[scene] = str(out)
        print(f"ok: {out}")
    print(json.dumps(results, ensure_ascii=False))


if __name__ == "__main__":
    main()
