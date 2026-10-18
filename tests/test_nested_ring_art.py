"""Every wheel effect shares the fixed wedge geometry and clear UV perimeter."""
from pathlib import Path
import runpy
import struct

import numpy as np

root = Path(__file__).resolve().parents[1]
art = runpy.run_path(str(root / "tools" / "render_ring_art.py"))
render = art["render"]
layers = ("Pattern", "Border", "Shadow", "Relief", "Halo")
size = art["SIZE"]
coord = (np.arange(size, dtype=np.float32) + .5 - size/2) / (size/2)
dx, dy = np.meshgrid(coord, -coord)
radius = np.hypot(dx, dy) / art["ART_RADIUS"]
angle = np.abs(np.arctan2(dx, dy))

for tier in (0, 1, 2):
    for count in range(1, 25):
        lower = (.42, .70, .74)[tier]
        limit = art["sweep"](count, tier) / count / 2
        distance = np.minimum.reduce((radius-lower, 1-radius,
                                      (limit-angle)*np.maximum(radius, lower)))
        masks = {}
        for layer in layers:
            data = (root / "Textures" / f"Wheel{layer}T{tier}N{count:02d}.blp").read_bytes()
            assert struct.unpack_from("<4sI4BII", data) == (b"BLP2", 1, 3, 8, 8, 0, 512, 512)
            assert len(data) == 1172 + size*size*4
            assert data == render(tier, count, layer), (tier, count, layer)
            pixels = np.frombuffer(data, dtype=np.uint8, offset=1172).reshape(size, size, 4)
            alpha = pixels[:, :, 3]
            masks[layer] = alpha
            assert alpha[0, 0] == alpha[-1, -1] == alpha[256, 256] == 0
            assert np.any(alpha), (tier, count, layer)
            assert not np.any(alpha[[0, -1], :]) and not np.any(alpha[:, [0, -1]]), "UV perimeter must be clear"
            if layer == "Border":
                assert np.any(pixels[:, :, 2][alpha > 0] > pixels[:, :, 0][alpha > 0]), "BLP border decodes as warm gold"
            elif layer == "Pattern":
                assert alpha[18, 256] > 0, "segment is centered at twelve o'clock"
                assert alpha.max() == 255, "pattern interior must be opaque before UI fade"
            elif layer == "Shadow":
                assert np.all(pixels[:, :, :3][alpha > 0] == 255), "neutral tintable shadow RGB; Lua defaults black"
                assert alpha.max() <= 180, "shadow must be translucent"
            elif layer == "Relief":
                assert alpha.max() <= 65, "relief must be subtle"
                assert np.any(pixels[:, :, 0][alpha > 0] == 255), "white highlights"
                assert np.any(pixels[:, :, 0][alpha > 0] == 20), "dark inner shading"
                assert not np.any(alpha[masks["Pattern"] == 0]), "relief stays within wedge"
            else:
                assert np.all(pixels[:, :, :3][alpha > 0] == 255), "white tintable ADD glow"
                assert alpha.max() <= 150, "halo must be translucent"
                core_y = round(size/2 - 248*(lower+1)/2)
                assert alpha[core_y, 256] <= 1, "halo cannot fill the wedge interior"
            if layer in ("Shadow", "Halo"):
                # The effects blur only the same signed wedge edge, with a
                # bounded external skirt; neither can spill to another sector.
                assert not np.any(alpha[distance < -.041]), (tier, count, layer, "escaped wedge")
                assert not np.any(alpha[radius >= 1.018]), (tier, count, layer, "escaped disk")
                assert np.any(alpha[masks["Pattern"] > 0]), "effect aligns with its pattern"

print("All 360 nested ring layers byte-match; effects bounded to matching geometry with clear perimeter")
for layer in ("Pattern", "Border"):
    inner = (root / "Textures" / f"Wheel{layer}T0N01.blp").read_bytes()[1172+3::4]
    outer = (root / "Textures" / f"Wheel{layer}T1N01.blp").read_bytes()[1172+3::4]
    # The patterned fill reaches the joint; narrow gold strokes cover its immediate seam.
    pixels = (197, 198, 199, 200, 201) if layer == "Pattern" else (199, 200, 201)
    for pixel_radius in pixels:
        root_y = round(256 - 248 * pixel_radius / 200)
        child_y = round(256 - 248 * pixel_radius / (200 / .70))
        root_alpha = inner[root_y * 512 + 256] if root_y >= 0 else 0
        child_alpha = outer[child_y * 512 + 256]
        assert max(root_alpha, child_alpha) > 0, (layer, pixel_radius, "transparent tier seam")
print("Shared radial boundaries have no transparent gap")