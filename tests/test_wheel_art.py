"""Check that all supported wheel sizes have centered, transparent BLP sectors."""
import struct
import runpy
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "Textures"
render = runpy.run_path(str(root.parent / "tests/generate_wheel_art.py"))["asset"]
for count in range(1, 25):
    for kind in ("Sector", "Glow"):
        data = (root / f"Wheel{kind}{count:02}.blp").read_bytes()
        assert struct.unpack_from("<4sI4BII", data) == (b"BLP2", 1, 3, 8, 8, 0, 512, 512)
        offset, length = struct.unpack_from("<I", data, 20)[0], struct.unpack_from("<I", data, 84)[0]
        assert offset == 1172 and length == 512 * 512 * 4 and len(data) == offset + length
        alpha = data[offset+3::4]
        assert any(alpha), (count, kind)
        assert alpha[0] == alpha[511] == alpha[-1] == 0, (count, kind)
        assert alpha[256 * 512 + 256] == 0, (count, kind)
        assert alpha[18 * 512 + 256] > 0, (count, kind)
        assert any(0 < value < 60 for value in alpha), (count, kind, "antialiasing")
        if count in (1, 7, 24):
            assert data == render(count, kind == "Glow"), (count, kind)
print("48 wheel sector/glow BLP assets passed structural and geometry checks")

art = runpy.run_path(str(root.parent / "tests/generate_wheel_trim.py"))
for count in range(1, 25):
    data = (root / f"WheelTrim{count:02}.blp").read_bytes()
    assert struct.unpack_from("<4sI4BII", data) == (b"BLP2", 1, 3, 8, 8, 0, 512, 512)
    assert len(data) == 1172 + 512 * 512 * 4
    assert data[1172+3] == 0 and data[1172+3+512*512*4-4] == 0
    if count in (1, 7, 8, 24):
        assert data == art["trim"](count), count
center = (root / "WheelCenter.blp").read_bytes()
assert center == art["medallion"]()
assert center[1172+3] == 0
print("24 gold trim BLPs and medallion passed structural and regeneration checks")
