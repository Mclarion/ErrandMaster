"""Target card textures use the same BGRA BLP2 layout as the other WoW art."""
from pathlib import Path
import runpy
import struct
from PIL import Image

root = Path(__file__).resolve().parents[1]
for name in ("CardFrame", "CardPattern"):
    data = (root / "Textures" / f"{name}.blp").read_bytes()
    assert struct.unpack_from("<4sI4BII", data) == (b"BLP2", 1, 3, 8, 8, 0, 512, 128)
    offset = struct.unpack_from("<I", data, 20)[0]
    assert offset == 1172, f"{name} needs a complete BLP2 header/palette"
    assert len(data) == offset + 512 * 128 * 4
    image = Image.frombytes("RGBA", (512, 128), data[offset:], "raw", "BGRA")
    assert image.getpixel((256, 64))[3] == (0 if name == "CardFrame" else 255)
    assert image.getpixel((15, 15))[3] == (255 if name == "CardFrame" else 0)
checker = runpy.run_path(str(root / "tests" / "build_card_assets.py"))
checker["build"](check=True)
print("Card layers decode as source-colored gold frame and separate tinted interior")
