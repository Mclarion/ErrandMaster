"""Validate bundled icon structure without requiring the source artwork or Pillow."""
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
classes = ("DeathKnight", "DemonHunter", "Druid", "Evoker", "Hunter", "Mage",
           "Monk", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior")
for name in ("Bank", *("Class" + klass for klass in classes),
             *("Service" + name for name in
               ("Repair", "Auction", "Mail", "Vendor", "Custom", "Trainer",
                "Travel", "Quests", "Skills", "Items", "Flight", "Portal",
                "Boat", "Hearthstone", "Favorites", "Lock", "Unlock"))):
    data = (root / "Textures" / (name + ".blp")).read_bytes()
    size = 128 if name.startswith("Service") else 256 if name.startswith("Class") else 64
    assert struct.unpack_from("<4sI4BII", data) == (b"BLP2", 1, 3, 8, 8, 0, size, size), name
    offset = struct.unpack_from("<I", data, 20)[0]
    length = struct.unpack_from("<I", data, 84)[0]
    assert offset == 1172 and length == size * size * 4 and len(data) == offset + length, name
    assert any(data[offset + i * 4 + 3] for i in range(size * size)), name
print("31 bundled wheel icon assets passed structural validation")
