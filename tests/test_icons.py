"""Validate bundled icon structure without requiring the source artwork or Pillow."""
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
classes = ("DeathKnight", "DemonHunter", "Druid", "Evoker", "Hunter", "Mage",
           "Monk", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior")
for name in ("Bank", *("Class" + klass for klass in classes)):
    data = (root / "Textures" / (name + ".blp")).read_bytes()
    assert struct.unpack_from("<4sI4BII", data) == (b"BLP2", 1, 3, 8, 8, 0, 64, 64), name
    offset = struct.unpack_from("<I", data, 20)[0]
    size = struct.unpack_from("<I", data, 84)[0]
    assert offset == 1172 and size == 64 * 64 * 4 and len(data) == offset + size, name
    assert any(data[offset + i * 4 + 3] for i in range(64 * 64)), name
print("14 bundled wheel icon assets passed structural validation")
