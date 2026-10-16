"""Build antialiased gold trim and map medallion for the radial wheel."""
from math import cos, pi, sin
from pathlib import Path
import struct

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "Textures"
SIZE = 512
DRAW = 1024  # Downsample once; the client receives transparent 512px BLPs.
C = DRAW // 2
R = C


def blp(image):
    image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    raw = image.tobytes()
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
    # Jewels mark major directions, not all 24 narrow seams.
    jewels = min(count, 8) if count <= 8 else 4
    for index in range(jewels):
        angle = pi / 2 + index * 2 * pi / jewels
        x, y = point(.947, angle)
        d.polygon(((x, y - 24), (x + 18, y), (x, y + 24), (x - 18, y)),
                  fill=(27, 29, 31, 254), outline=(229, 181, 101, 244), width=4)
        d.polygon(((x, y - 17), (x + 12, y), (x, y + 17), (x - 12, y)),
                  fill=(26, 124, 147, 241))
        d.line(((x - 3, y - 7), (x, y - 11)), fill=(194, 243, 238, 221), width=3)
    return blp(image)


def medallion():
    image = Image.new("RGBA", (DRAW, DRAW))
    d = ImageDraw.Draw(image)
    d.ellipse(bounds(.495), fill=(16, 26, 34, 248))
    d.ellipse(bounds(.453), fill=(150, 129, 92, 255))
    d.ellipse(bounds(.425), fill=(197, 178, 135, 255))
    d.ellipse(bounds(.410), outline=(87, 98, 80, 113), width=5)
    # Faint cartographic strokes do not compete with the live hub label.
    d.line(((260, 685), (332, 641), (429, 669), (505, 582), (596, 594),
            (691, 507), (776, 472)), fill=(66, 130, 130, 124), width=18, joint="curve")
    d.line(((260, 685), (332, 641), (429, 669), (505, 582), (596, 594),
            (691, 507), (776, 472)), fill=(183, 218, 196, 83), width=4, joint="curve")
    for x, y in ((305, 393), (422, 344), (652, 367), (715, 701)):
        d.polygon(((x - 43, y + 36), (x, y - 40), (x + 47, y + 36)),
                  fill=(79, 104, 82, 124))
        d.line(((x - 40, y + 38), (x, y - 34), (x + 45, y + 38)),
               fill=(71, 79, 61, 105), width=6)
    # Dark nameplate lets a live, sharp FontString replace baked text.
    d.rounded_rectangle((308, 470, 716, 554), radius=20,
                        fill=(25, 35, 42, 243), outline=(235, 200, 128, 247), width=9)
    return blp(image)


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    for count in range(1, 25):
        (ROOT / f"WheelTrim{count:02d}.blp").write_bytes(trim(count))
    (ROOT / "WheelCenter.blp").write_bytes(medallion())
    print("Rendered 24 gold wheel trims and map medallion")
