"""Build the art-style comparison images used in acceptance cards.

Usage (repo root, after an autoshot run):
    python tools/art/compare_styles.py <autoshot_dir> <out_prefix>

Writes <out_prefix>-styles.jpg  (same battle frame in every style, 2x2)
       <out_prefix>-lineups.jpg (all characters, enemies and props per style)
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = str(ROOT / "assets" / "fonts" / "NotoSansCJKsc-Regular.otf")
STYLES = [("cel", "A 晴港赛璐璐"), ("watercolor", "B 雾色水彩"), ("pixel", "C 像素点阵")]
SPRITES = [("units", n) for n in ["blade", "warden", "archer", "caster", "medic"]]
SPRITES += [("enemies", n) for n in ["slime", "hound", "brute"]]
SPRITES += [("props", n) for n in ["gate", "lighthouse"]]
GOLD = (255, 211, 107)


def styles_grid(shots: Path, out: Path) -> None:
    items = STYLES + [("greybox", "（对照）v0.1 灰盒")]
    font = ImageFont.truetype(FONT, 34)
    w, h, pad, lab = 960, 540, 12, 52
    img = Image.new("RGB", (w * 2 + pad * 3, (h + lab) * 2 + pad * 3), (12, 15, 22))
    draw = ImageDraw.Draw(img)
    for i, (sid, name) in enumerate(items):
        shot = Image.open(shots / f"05_midgame_{sid}.png").convert("RGB").resize((w, h), Image.LANCZOS)
        x = pad + (i % 2) * (w + pad)
        y = pad + (i // 2) * (h + lab + pad)
        draw.text((x + 6, y + 6), name, font=font, fill=GOLD)
        img.paste(shot, (x, y + lab))
    img.save(out, quality=88)


def lineups(out: Path) -> None:
    font = ImageFont.truetype(FONT, 30)
    pad, lab = 18, 46
    rows = []
    for sid, name in STYLES:
        ims = [Image.open(ROOT / "assets" / "art" / sid / f / f"{n}.png") for f, n in SPRITES]
        w = sum(i.width for i in ims) + pad * (len(ims) + 1)
        h = max(i.height for i in ims) + pad * 2 + lab
        row = Image.new("RGBA", (w, h), (22, 28, 40, 255))
        ImageDraw.Draw(row).text((pad, 8), name, font=font, fill=GOLD)
        x = pad
        for i in ims:
            row.alpha_composite(i, (x, h - pad - i.height))
            x += i.width + pad
        rows.append(row)
    img = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows)), (12, 15, 22))
    y = 0
    for r in rows:
        img.paste(r, (0, y), r)
        y += r.height
    img.save(out, quality=90)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    shots, prefix = Path(sys.argv[1]), sys.argv[2]
    styles_grid(shots, Path(prefix + "-styles.jpg"))
    lineups(Path(prefix + "-lineups.jpg"))
    print("wrote", prefix + "-styles.jpg,", prefix + "-lineups.jpg")


if __name__ == "__main__":
    main()
