"""Validate the fully transparent uncompressed WoW cursor texture."""
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
data = (root / "Textures/HiddenCursor.blp").read_bytes()
assert data[:4] == b"BLP2"
assert struct.unpack_from("<I", data, 4)[0] == 1
assert data[8:12] == bytes((3, 8, 8, 0))  # Raw BGRA, alpha8, one mip.
width, height = struct.unpack_from("<II", data, 12)
assert (width, height) == (32, 32)
assert struct.unpack_from("<I", data, 20)[0] == 1172
assert struct.unpack_from("<I", data, 84)[0] == width * height * 4
assert len(data) == 1172 + width * height * 4
assert not any(data[1172:])  # All BGRA pixels (including alpha) transparent.
print("cursor texture format passed")
