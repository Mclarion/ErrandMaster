"""Regenerate count-specific alpha BLP2 art: python3 tests/generate_wheel_art.py.

Keep the circle inside its square texture to allow client-side rotation.
"""
from math import atan2, hypot, pi
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1] / "Textures"
SIZE = 128


def asset(count, glow):
    raw = bytearray()
    half = SIZE / 2
    angle_limit = pi / count
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = (x + .5 - half) / half, (half - y - .5) / half
            radius = hypot(dx, dy)
            angle = abs(atan2(dx, dy))
            border = min(radius - .31, .93 - radius,
                         (angle_limit - angle) * max(radius, .31))
            if glow:
                edge = max(0, 1 - abs(border) / .055)
                alpha = int(75 * edge) if .26 < radius < .99 and angle < angle_limit + .08 else 0
            elif border >= 0:
                alpha = 210 if border < .018 else 66
            else:
                alpha = 0
            raw.extend((255, 255, 255, alpha))
    header = struct.pack("<4sI4BII", b"BLP2", 1, 3, 8, 8, 0, SIZE, SIZE)
    header += struct.pack("<16I", 1172, *([0] * 15))
    header += struct.pack("<16I", len(raw), *([0] * 15))
    header += bytes(1024)
    assert len(header) == 1172
    return header + raw


if __name__ == "__main__":
    for count in range(1, 25):
        for glow in (False, True):
            name = f"Wheel{'Glow' if glow else 'Sector'}{count:02d}.blp"
            (ROOT / name).write_bytes(asset(count, glow))
    print("Rendered 48 count-specific wheel assets")
