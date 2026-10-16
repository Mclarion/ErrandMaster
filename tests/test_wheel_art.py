"""Check that all supported wheel sizes have centered, transparent BLP sectors."""
import struct
import runpy
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "Textures"
render = runpy.run_path(str(root.parent / "tests/generate_wheel_art.py"))["asset"]
for count in range(1, 25):
    for kind in ("Sector", "Glow"):
        data = (root / f"Wheel{kind}{count:02}.blp").read_bytes()
        assert struct.unpack_from("<4sI4BII", data) == (b"BLP2", 1, 3, 8, 8, 0, 128, 128)
        offset, length = struct.unpack_from("<I", data, 20)[0], struct.unpack_from("<I", data, 84)[0]
        assert offset == 1172 and length == 128 * 128 * 4 and len(data) == offset + length
        alpha = data[offset+3::4]
        assert any(alpha), (count, kind)
        assert alpha[0] == alpha[127] == alpha[-1] == 0, (count, kind)
        assert alpha[64 * 128 + 64] == 0, (count, kind)
        assert alpha[5 * 128 + 64] > 0, (count, kind)
        if count in (1, 7, 24):
            assert data == render(count, kind == "Glow"), (count, kind)
print("48 wheel sector/glow BLP assets passed structural and geometry checks")
