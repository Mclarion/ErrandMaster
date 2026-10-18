"""Build jewel-free gold trim and import the user's wheel UI elements."""
from math import cos, pi, sin
from pathlib import Path
import struct

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "Textures"
ART = ROOT.parent / "art/wheel-icons/UI Elements"
SIZE = 512
DRAW = 1024  # Downsample once; the client receives transparent 512px BLPs.
C = DRAW // 2
R = C


def blp(image):
    image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    raw = image.tobytes("raw", "BGRA")
    header = struct.pack("<4sI4BII", b"BLP2", 1, 3, 8, 8, 0, SIZE, SIZE)
    header += struct.pack("<16I", 1172, *([0] * 15))
    header += struct.pack("<16I", len(raw), *([0] * 15)) + bytes(1024)
    assert len(header) == 1172
    return header + raw


def bounds(fraction):
    delta = int(R * fraction)
    return (C - delta, C - delta, C + delta, C + delta)


def point(fraction, angle):
    return (round(C + R * fraction * cos(angle)),
            round(C - R * fraction * sin(angle)))


def trim(count):
    if not 1 <= count <= 24:
        raise ValueError(count)
    image = Image.new("RGBA", (DRAW, DRAW))
    d = ImageDraw.Draw(image)
    # Recessed outer edge, narrow double gilt rim, and a clear inset edge.
    d.ellipse(bounds(.981), outline=(8, 13, 20, 150), width=21)
    d.ellipse(bounds(.955), outline=(57, 39, 25, 243), width=37)
    d.ellipse(bounds(.975), outline=(205, 159, 80, 236), width=10)
    d.ellipse(bounds(.941), outline=(241, 211, 140, 222), width=7)
    d.ellipse(bounds(.918), outline=(67, 44, 26, 193), width=6)
    d.arc(bounds(.960), 206, 322, fill=(255, 235, 172, 169), width=5)
    d.arc(bounds(.960), 15, 119, fill=(255, 235, 172, 128), width=4)
    # Gold seams stay independent of the tint of each category sector.
    for index in range(count):
        angle = pi / 2 + (2 * index + 1) * pi / count
        inside, outside = point(.326, angle), point(.924, angle)
        d.line((inside, outside), fill=(25, 22, 23, 201), width=13)
        d.line((inside, outside), fill=(179, 139, 82, 227), width=6)
        d.line((inside, outside), fill=(251, 221, 158, 142), width=2)
    # An engraved center ring separates icon space from the readable hub.
    d.ellipse(bounds(.342), outline=(12, 17, 25, 219), width=15)
    d.ellipse(bounds(.331), outline=(190, 145, 79, 239), width=10)
    d.ellipse(bounds(.310), outline=(251, 222, 158, 216), width=5)
    return blp(image)


def from_source(name):
    with Image.open(ART / name) as original:
        if original.size != (1254, 1254) or original.mode != "RGBA":
            raise ValueError(f"unexpected UI element: {name}")
        image = original.copy()
    if image.getchannel("A").getextrema() != (0, 255):
        raise ValueError(f"missing transparency: {name}")
    return blp(image)

def center_asset():
    return from_source("ErrandMasterCenterEmblem.png")

def hover_center():
    """Quiet circular name plaque, preserving the emblem's gold perimeter."""
    image=Image.new("RGBA",(DRAW,DRAW))
    painter=ImageDraw.Draw(image)
    painter.ellipse((20,20,DRAW-20,DRAW-20),fill=(18,23,30,247),
                    outline=(220,177,94,248),width=28)
    painter.ellipse((47,47,DRAW-47,DRAW-47),outline=(92,64,38,215),width=12)
    return blp(image)

def medallion_asset(color, state):
    if color not in ("Green", "Blue", "Purple", "Red", "Yellow", "Orange", "Pink", "Cyan", "White") or state not in ("Active", "Inactive"):
        raise ValueError((color, state))
    # Pad the untouched source (not cropped or retinted) into a rotation-safe
    # square. The Lua widget is jewelDiameter / .70, just like sector art.
    with Image.open(ART / f"{color}_{state}_Medallion.png") as original:
        source = original.convert("RGBA")
    canvas = Image.new("RGBA", (SIZE, SIZE))
    side = round(SIZE * .70)
    canvas.alpha_composite(source.resize((side,side),Image.Resampling.LANCZOS),
                           ((SIZE-side)//2,(SIZE-side)//2))
    return blp(canvas)


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    for count in range(1, 25):
        (ROOT / f"WheelTrim{count:02d}.blp").write_bytes(trim(count))
    (ROOT / "WheelCenter.blp").write_bytes(center_asset())
    (ROOT / "WheelCenterHover.blp").write_bytes(hover_center())
    for color in ("Green", "Blue", "Purple", "Red", "Yellow", "Orange", "Pink", "Cyan", "White"):
        for state in ("Active", "Inactive"):
            (ROOT / f"Medallion{color}{state}.blp").write_bytes(medallion_asset(color, state))
    print("Rendered jewel-free gold trims and imported center plus 18 medallions")
