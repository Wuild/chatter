"""Extract class art using GatherLite's edge-connected background removal.

Requires Pillow. Retains source pixels; outputs power-of-two RGBA TGA assets.
"""
from collections import deque
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CLASSES = ('warrior', 'mage', 'rogue', 'druid', 'hunter', 'shaman',
           'priest', 'warlock', 'paladin', 'deathknight', 'monk', 'demonhunter')


def cutout(image, threshold=40):
    image = image.convert('RGBA')
    pixels = image.load()
    width, height = image.size
    background = set()
    queue = deque((x, y) for x in range(width) for y in (0, height - 1))
    queue.extend((x, y) for y in range(height) for x in (0, width - 1))
    while queue:
        x, y = queue.popleft()
        if not (0 <= x < width and 0 <= y < height) or (x, y) in background:
            continue
        if pixels[x, y][3] and max(pixels[x, y][:3]) > threshold:
            continue
        background.add((x, y))
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
    result = image.copy()
    output = result.load()
    for y in range(height):
        for x in range(width):
            r, g, b, alpha = pixels[x, y]
            if (x, y) in background:
                output[x, y] = (0, 0, 0, 0)
            elif any(point in background for point in ((x-1, y), (x+1, y), (x, y-1), (x, y+1))):
                alpha = min(alpha, max(0, round((max(r, g, b) - threshold) * 255 / (80 - threshold))))
                if 0 < alpha < 255:
                    output[x, y] = tuple(min(255, round(v * 255 / alpha)) for v in (r, g, b)) + (alpha,)
                elif alpha == 0:
                    output[x, y] = (0, 0, 0, 0)
    canvas = Image.new('RGBA', (64, 64))
    canvas.paste(result, ((64 - width) // 2, (64 - height) // 2))
    return canvas


def main():
    with Image.open(ROOT / 'assets/classes/source/class-atlas.png') as atlas:
        assert atlas.size == (256, 256)
        for index, name in enumerate(CLASSES):
            x, y = (index % 4) * 64, (index // 4) * 64
            # Remove the baked square bevel before separating background pixels.
            result = cutout(atlas.crop((x + 8, y + 8, x + 56, y + 56)))
            result.save(ROOT / f'assets/classes/{name}.tga')


if __name__ == '__main__':
    main()
