"""Rebuild/verify the independently tinted card interior and untouched gold frame.

Run: python3 tests/build_card_assets.py [--check]
"""
from pathlib import Path
import hashlib
import struct
import sys
from PIL import Image, ImageDraw, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/wheel-icons/BackgroundCardPattern.png'
REFERENCE = ROOT / '.testdeps/BackgroundCardPattern.png'
TARGET = ROOT / 'Textures'
SIZE = (512, 128)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def blp(image):
    image = image.convert('RGBA')
    width, height = image.size
    header = struct.pack('<4sI4BII', b'BLP2', 1, 3, 8, 8, 0, width, height)
    offsets = struct.pack('<16I', 1172, *([0] * 15))
    lengths = struct.pack('<16I', width * height * 4, *([0] * 15))
    return header + offsets + lengths + bytes(1024) + image.tobytes('raw', 'BGRA')


def build(check=False):
    if REFERENCE.is_file():
        assert digest(SOURCE) == digest(REFERENCE), 'source differs from supplied reference'
    image = Image.open(SOURCE).convert('RGBA')
    assert image.size == (2172, 724)
    # Punch the ivory interior out of the original gold/gem layer. The same
    # antialiased rounded mask confines the grayscale pattern underneath it.
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((155, 105, 2017, 619), radius=100, fill=255)
    outer = ImageChops.invert(mask)
    frame = image.copy()
    frame.putalpha(outer)
    gray = image.convert('L').point(lambda x: round(65 + x * 0.60))
    pattern = Image.merge('RGBA', (gray, gray, gray, mask))
    results = {'CardFrame.blp': frame, 'CardPattern.blp': pattern}
    # Gems and gold remain original RGB; only the interior can be tinted.
    assert frame.getpixel((80, 60))[:3] == image.getpixel((80, 60))[:3]
    assert frame.getpixel((80, 60))[3] == 255
    assert frame.getpixel((1086, 362))[3] == 0
    assert pattern.getpixel((1086, 362))[3] == 255
    assert pattern.getpixel((80, 60))[3] == 0
    for name, layer in results.items():
        data = blp(layer.resize(SIZE, Image.Resampling.LANCZOS))
        path = TARGET / name
        if check:
            assert path.read_bytes() == data, f'{name} does not match source'
        else:
            path.write_bytes(data)
        print(name, hashlib.sha256(data).hexdigest(), len(data))
    print('source', digest(SOURCE))


if __name__ == '__main__':
    build('--check' in sys.argv)
