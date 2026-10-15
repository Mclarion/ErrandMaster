"""Build the tiny uncompressed BGRA BLP2 cursor used only while the wheel is open."""
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
size = 32
pixel_bytes = size * size * 4
header_bytes = 148
palette_bytes = 256 * 4
first_offset = header_bytes + palette_bytes
header = struct.pack("<4sI4BII", b"BLP2", 1, 3, 8, 8, 0, size, size)
header += struct.pack("<16I", first_offset, *([0] * 15))
header += struct.pack("<16I", pixel_bytes, *([0] * 15))
assert len(header) == header_bytes
output = root / "Textures" / "HiddenCursor.blp"
output.parent.mkdir(exist_ok=True)
output.write_bytes(header + bytes(palette_bytes + pixel_bytes))
print(f"Created {output}")
