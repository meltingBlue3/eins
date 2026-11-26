"""Turn raw AI-generated sheets into game sprites.

Usage (repo root):
    python tools/art/process_style.py <style> [<style> ...]

Reads  art_src/raw/<style>/{units,enemies,tiles}.png
Writes assets/art/<style>/{units,enemies,props,tiles}/*.png and art_src/preview/<style>.png

Sheets are expected to hold one horizontal row of items on a transparent (or flat-colour)
background; tiles.png is a 2x2 grid. Sprites are stored at 2x their on-screen size and are
bottom-anchored (the bottom edge is where the feet touch the ground).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "art_src" / "raw"
OUT = ROOT / "assets" / "art"
PREVIEW = ROOT / "art_src" / "preview"

STORE_SCALE = 2  # stored pixels per on-screen pixel

# Pixel styles are rebuilt on a true pixel grid: on-screen size / PIXEL_SIZE art pixels.
PIXEL_STYLES = {"pixel": 2}

UNITS = ["blade", "warden", "archer", "caster", "medic"]
UNIT_HEIGHT = 88  # on-screen height of a typical unit

# name -> (folder, on-screen fit box w, h)
ENEMY_SHEET = [
    ("slime", "enemies", 60, 50),
    ("hound", "enemies", 84, 58),
    ("brute", "enemies", 104, 96),
    ("gate", "props", 96, 104),
    ("lighthouse", "props", 96, 150),
]
TILES = [("ground", 0, 0), ("high", 1, 0), ("void", 0, 1), ("wall", 1, 1)]
TILE_SIZE = 80
TILE_SPAN = 2  # one texture covers 2x2 cells; the game picks the quarter by cell parity


def load_rgba(path: Path) -> np.ndarray:
    img = np.asarray(Image.open(path).convert("RGBA")).astype(np.uint8)
    border = np.concatenate([img[0], img[-1], img[:, 0], img[:, -1]])
    if np.median(border[:, 3]) < 16:
        return img  # real transparency
    # Flat background: key out pixels close to the border colour that touch the border.
    bg = np.median(border[:, :3], axis=0)
    dist = np.linalg.norm(img[:, :, :3].astype(float) - bg, axis=2)
    near = dist < 38
    labels, _ = ndimage.label(near)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg_mask = np.isin(labels, edge_labels[edge_labels > 0])
    img = img.copy()
    img[bg_mask, 3] = 0
    print(f"  keyed out flat background {bg.astype(int).tolist()} in {path.name}")
    return img


def clean_alpha(img: np.ndarray) -> np.ndarray:
    """Drop faint haze and tiny specks so segmentation sees solid shapes only."""
    img = img.copy()
    solid = img[:, :, 3] > 40
    labels, n = ndimage.label(solid)
    if n:
        sizes = ndimage.sum(solid, labels, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes >= 150
        img[~keep[labels] & ~(img[:, :, 3] <= 40), 3] = 0
    img[img[:, :, 3] <= 12, 3] = 0
    # Defringe: generators leave saturated colour noise in half-transparent edge pixels.
    # Give every soft pixel the colour of its nearest solid pixel, keeping its alpha.
    opaque = img[:, :, 3] >= 230
    if opaque.any():
        _, (iy, ix) = ndimage.distance_transform_edt(~opaque, return_indices=True)
        soft = (img[:, :, 3] > 0) & ~opaque
        img[soft, :3] = img[iy[soft], ix[soft], :3]
    return img


def split_row(img: np.ndarray, count: int) -> list:
    """Split a one-row sheet into `count` bounding boxes using the column profile."""
    mask = img[:, :, 3] > 40
    cols = mask.sum(axis=0) > 1
    runs, start = [], None
    for x, on in enumerate(cols):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append([start, x])
            start = None
    if start is not None:
        runs.append([start, len(cols)])
    runs = [r for r in runs if r[1] - r[0] >= 6]
    while len(runs) > count:
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = int(np.argmin(gaps))
        runs[i] = [runs[i][0], runs[i + 1][1]]
        del runs[i + 1]
    while len(runs) < count:
        widths = [r[1] - r[0] for r in runs]
        i = int(np.argmax(widths))
        a, b = runs[i]
        lo, hi = a + (b - a) // 5, b - (b - a) // 5
        cut = lo + int(np.argmin(mask[:, lo:hi].sum(axis=0)))
        runs[i:i + 1] = [[a, cut], [cut, b]]
        print(f"  warning: items touch, cut at x={cut}")
    boxes = []
    for a, b in runs:
        rows = np.where(mask[:, a:b].any(axis=1))[0]
        boxes.append((a, rows[0], b, rows[-1] + 1))
    return boxes


def crop(img: np.ndarray, box) -> Image.Image:
    """Crop one item and drop stray bits of its neighbours (small detached pieces)."""
    a, t, b, btm = box
    part = img[t:btm, a:b].copy()
    solid = part[:, :, 3] > 40
    labels, n = ndimage.label(solid)
    if n > 1:
        sizes = ndimage.sum(solid, labels, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes >= sizes.max() * 0.03
        kept = keep[labels]
        near = ndimage.binary_dilation(kept, iterations=6)
        part[~near, 3] = 0
    ys, xs = np.where(part[:, :, 3] > 12)
    return Image.fromarray(part[ys.min():ys.max() + 1, xs.min():xs.max() + 1])


def pixelize(sprite: Image.Image, w: int, h: int, colors: int = 0) -> Image.Image:
    """Resample onto a true pixel grid with hard alpha; optionally limit the palette.

    Palette reduction is off by default: median cut drops small bright details
    such as the fog creatures' cyan eyes.
    """
    small = sprite.resize((max(1, w), max(1, h)), Image.BOX)
    arr = np.asarray(small).copy()
    alpha = arr[:, :, 3] >= 110
    if colors:
        rgb = Image.fromarray(arr[:, :, :3]).quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        arr[:, :, :3] = np.asarray(rgb.convert("RGB"))
    arr[:, :, 3] = np.where(alpha, 255, 0)
    return Image.fromarray(arr)


def scale_sprite(sprite: Image.Image, factor: float, pixel: int) -> Image.Image:
    """factor maps source pixels to on-screen pixels."""
    w = sprite.width * factor
    h = sprite.height * factor
    if pixel:
        art = pixelize(sprite, round(w / pixel), round(h / pixel))
        s = pixel * STORE_SCALE
        return art.resize((art.width * s, art.height * s), Image.NEAREST)
    return sprite.resize((max(1, round(w * STORE_SCALE)), max(1, round(h * STORE_SCALE))), Image.LANCZOS)


def save(img: Image.Image, style: str, folder: str, name: str) -> Path:
    path = OUT / style / folder / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    return path


def process_units(style: str, pixel: int) -> list:
    img = clean_alpha(load_rgba(RAW / style / "units.png"))
    boxes = split_row(img, len(UNITS))
    sprites = [crop(img, b) for b in boxes]
    # One shared scale keeps the relative sizes the artist drew.
    median_h = float(np.median([s.height for s in sprites]))
    factor = UNIT_HEIGHT / median_h
    out = []
    for name, s in zip(UNITS, sprites):
        out.append(save(scale_sprite(s, factor, pixel), style, "units", name))
    return out


def process_enemies(style: str, pixel: int) -> list:
    img = clean_alpha(load_rgba(RAW / style / "enemies.png"))
    boxes = split_row(img, len(ENEMY_SHEET))
    out = []
    for (name, folder, fw, fh), b in zip(ENEMY_SHEET, boxes):
        s = crop(img, b)
        factor = min(fw / s.width, fh / s.height)
        out.append(save(scale_sprite(s, factor, pixel), style, folder, name))
    return out


def process_tiles(style: str, pixel: int) -> list:
    src = Image.open(RAW / style / "tiles.png").convert("RGBA")
    hw, hh = src.width // 2, src.height // 2
    inset = int(min(hw, hh) * 0.04)
    out = []
    for name, cx, cy in TILES:
        q = src.crop((cx * hw + inset, cy * hh + inset, (cx + 1) * hw - inset, (cy + 1) * hh - inset))
        span = TILE_SIZE * TILE_SPAN
        if pixel:
            n = span // pixel
            art = pixelize(q, n, n, 24)
            s = pixel * STORE_SCALE
            img = art.resize((n * s, n * s), Image.NEAREST)
        else:
            img = q.resize((span * STORE_SCALE,) * 2, Image.LANCZOS)
        out.append(save(img, style, "tiles", name))
    return out


def preview(style: str, paths: list) -> None:
    """Contact sheet on the game's board colour, at on-screen size."""
    imgs = [Image.open(p) for p in paths]
    imgs = [i.resize((i.width // STORE_SCALE, i.height // STORE_SCALE), Image.LANCZOS) for i in imgs]
    pad = 16
    w = sum(i.width for i in imgs) + pad * (len(imgs) + 1)
    h = max(i.height for i in imgs) + pad * 2
    sheet = Image.new("RGBA", (w, h), (16, 20, 28, 255))
    x = pad
    for i in imgs:
        sheet.alpha_composite(i, (x, h - pad - i.height))
        x += i.width + pad
    PREVIEW.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW / f"{style}.png")


def main() -> None:
    styles = sys.argv[1:]
    if not styles:
        sys.exit(__doc__)
    for style in styles:
        pixel = PIXEL_STYLES.get(style, 0)
        print(f"[{style}]")
        paths = []
        for step, fname in ((process_units, "units"), (process_enemies, "enemies"), (process_tiles, "tiles")):
            if (RAW / style / f"{fname}.png").exists():
                paths += step(style, pixel)
            else:
                print(f"  skip {fname}.png (missing)")
        for p in paths:
            with Image.open(p) as im:
                print(f"  {p.relative_to(ROOT)}  {im.width}x{im.height}")
        if paths:
            preview(style, paths)


if __name__ == "__main__":
    main()
