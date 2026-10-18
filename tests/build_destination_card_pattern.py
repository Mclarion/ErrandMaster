"""Generate the destination-only softened pattern without changing shared art.

Run: python3 tests/build_destination_card_pattern.py [--check]
"""
from pathlib import Path
import math
import struct
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Textures/CardPattern.blp'
DEST = ROOT / 'Textures/DestinationCardPattern.blp'
GLOW = ROOT / 'Textures/DestinationButtonGlow.blp'
WIDTH, HEIGHT = 512, 128
OFFSET = 1172


def build(check=False):
    data = SOURCE.read_bytes()
    assert data[:4] == b'BLP2'
    assert struct.unpack_from('<II', data, 12) == (WIDTH, HEIGHT)
    assert struct.unpack_from('<I', data, 20)[0] == OFFSET
    image = Image.frombytes('RGBA', (WIDTH, HEIGHT), data[OFFSET:], 'raw', 'BGRA')
    pixels = image.load()
    for x in range(WIDTH):
        # Smoothstep at both ends: the ivory pattern remains legible centrally,
        # while its tinted interior disappears into the surrounding panel.
        edge = min(x, WIDTH - 1 - x) / (WIDTH * .17)
        edge = max(0., min(1., edge))
        fade = edge * edge * (3 - 2 * edge)
        for y in range(HEIGHT):
            r, g, b, alpha = pixels[x, y]
            pixels[x, y] = r, g, b, round(alpha * fade)
    result = data[:OFFSET] + image.tobytes('raw', 'BGRA')
    # A dedicated translucent radial halo avoids depending on client-bundled art.
    glow = Image.new('RGBA', (64, 64))
    glow_pixels = glow.load()
    for x in range(64):
        for y in range(64):
            radius = math.hypot(x - 31.5, y - 31.5) / 31.5
            opacity = round(230 * max(0., 1. - radius) ** 1.7)
            glow_pixels[x, y] = 255, 249, 207, opacity
    header = struct.pack('<4sI4BII', b'BLP2', 1, 3, 8, 8, 0, 64, 64)
    header += struct.pack('<16I', OFFSET, *([0] * 15))
    header += struct.pack('<16I', 64 * 64 * 4, *([0] * 15))
    glow_data = header + bytes(1024) + glow.tobytes('raw', 'BGRA')
    if check:
        assert GLOW.read_bytes() == glow_data, 'destination button glow is stale'
    else:
        GLOW.write_bytes(glow_data)
    assert glow.getpixel((32, 32))[3] > 200
    assert glow.getpixel((0, 0))[3] == 0
    if check:
        assert DEST.read_bytes() == result, 'destination card art is stale'
    else:
        DEST.write_bytes(result)
    return image


if __name__ == '__main__':
    image = build('--check' in sys.argv)
    assert image.getpixel((256, 64))[3] == 255
    assert image.getpixel((35, 64))[3] < image.getpixel((80, 64))[3]
    print('DestinationCardPattern.blp: softened edges, preserved central tint')
