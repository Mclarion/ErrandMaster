"""Build masked patterned slices, gold borders, and independent wheel effects.

Run: python3 tools/render_ring_art.py. One PNG source is preserved in art/wheel-icons.
Textures use BLP2 BGRA pixel order. All tiers have a transparent outside mask.
"""
from functools import lru_cache
from math import pi
from pathlib import Path
import struct

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZE = 512
# Transparent perimeter supports explicit rotated UVs without edge streaks.
ART_RADIUS = 248 / 256


def sweep(count, tier):
    return 2*pi if tier == 0 else min(5.5, max(pi/2, count*.42))


@lru_cache(maxsize=1)
def source():
    image = Image.open(ROOT / "art/wheel-icons/BackgroundPattern.png").convert("RGB")
    return np.asarray(image.resize((SIZE, SIZE), Image.Resampling.LANCZOS))


def render(tier, count, layer):
    assert tier in (0, 1, 2) and 1 <= count <= 24
    assert layer in ("Pattern", "Border", "Shadow", "Relief", "Halo")
    coord = (np.arange(SIZE, dtype=np.float32) + .5 - SIZE/2) / (SIZE/2)
    dx, dy = np.meshgrid(coord, -coord)
    radius = np.hypot(dx, dy) / ART_RADIUS
    angle = np.abs(np.arctan2(dx, dy))
    lower = (0.42, 0.70, 0.74)[tier]
    upper = 1.0  # Adjacent tiers meet at the same scaled radius.
    limit = sweep(count, tier) / count / 2
    distance = np.minimum.reduce((radius-lower, upper-radius,
                                  (limit-angle)*np.maximum(radius, lower)))
    coverage = np.clip((distance+.004)/.008, 0, 1)
    if layer == "Pattern":
        # Keep the user's linen/map pattern intact; Lua tints this layer only.
        rgb = source()
        alpha = np.asarray(np.rint(coverage*255), dtype=np.uint8)
    elif layer == "Border":
        rgb = np.empty((SIZE, SIZE, 3), dtype=np.uint8)
        # Untinted, layered gilt relief: dark engraved valley plus two warm
        # raised highlights and a small scrolling vine inside each sector.
        outer = np.exp(-((1-radius)/.015)**2)
        inner = np.exp(-((radius-lower)/.014)**2)
        ribs = np.exp(-((limit-angle)*np.maximum(radius,lower)/.013)**2)
        bevel = np.exp(-((1-radius-.028)/.012)**2)
        curl = np.exp(-((radius-(.87+.013*np.sin(angle*21)))/.009)**2)
        curl *= np.clip((.88-radius)/.035,0,1)*np.clip((radius-.76)/.08,0,1)
        edge = np.maximum.reduce((outer,inner,ribs*.94,bevel*.45,curl*.38))
        rgb[:] = (231, 173, 80)
        rgb[:,:,0] = np.clip(174+64*np.maximum(outer,inner)+
                             60*bevel+38*curl,0,255).astype('uint8')
        rgb[:,:,1] = np.clip(105+83*np.maximum(outer,inner)+
                             59*bevel+37*curl,0,255).astype('uint8')
        alpha = np.asarray(np.rint(coverage*np.clip(edge,0,1)*240),dtype=np.uint8)
    else:
        # Signed distance to the *same* inner/outer/side edges as the masks.
        # The physical disk is only 248px in a 256px UV half-plane; truncate
        # outward blur before the image boundary so rotated UVs cannot streak.
        perimeter = np.clip((1.018-radius)/.012, 0, 1)
        if layer == "Shadow":
            # Tintable white RGB with black vertex color at rest. Black source
            # pixels cannot be recolored by WoW's multiplicative vertex tint.
            rgb = np.full((SIZE, SIZE, 3), 255, dtype=np.uint8)
            # A wide, low-opacity black silhouette, extending just outside
            # the slice rather than duplicating the opaque pattern fill.
            softness = np.clip((distance+.035)/.065, 0, 1)
            strength = (0.32 + 0.68*np.exp(-(distance/.032)**2))
            opacity = softness*strength*perimeter*.70
        elif layer == "Relief":
            # White raised outer/leading edges and dark recessed inner/trailing
            # edges; the transparent overlay is composed with BLEND.
            outer_light = np.exp(-((1-radius-.012)/.023)**2)
            inner_dark = np.exp(-((radius-lower-.012)/.025)**2)
            leading_light = np.exp(-(((limit-angle)*np.maximum(radius,lower)-.010)/.024)**2)
            light = np.maximum(outer_light, leading_light*.65)
            dark = inner_dark*.75
            opacity = coverage*np.maximum(light*.22, dark*.19)
            rgb = np.empty((SIZE, SIZE, 3), dtype=np.uint8)
            value = np.where(light*.22 >= dark*.19, 255, 20).astype(np.uint8)
            rgb[:] = value[:, :, None]
        else:  # Halo: a luminous outline, never a filled wedge.
            rgb = np.full((SIZE, SIZE, 3), 255, dtype=np.uint8)
            glow = np.exp(-(distance/.025)**2)
            # A soft outer skirt and a fine brighter line on the actual edge.
            skirt = np.clip((distance+.040)/.012, 0, 1)
            opacity = glow*(.38 + .18*np.exp(-(distance/.007)**2))*perimeter*skirt
        alpha = np.asarray(np.rint(np.clip(opacity, 0, 1)*255), dtype=np.uint8)
    raw = np.dstack((rgb[:, :, ::-1], alpha)).tobytes()
    header = struct.pack("<4sI4BII", b"BLP2", 1, 3, 8, 8, 0, SIZE, SIZE)
    header += struct.pack("<16I", 1172, *([0]*15))
    header += struct.pack("<16I", len(raw), *([0]*15))
    header += bytes(1024)
    return header + raw


if __name__ == "__main__":
    for tier in (0, 1, 2):
        for count in range(1, 25):
            for layer in ("Pattern", "Border", "Shadow", "Relief", "Halo"):
                (ROOT / "Textures" / f"Wheel{layer}T{tier}N{count:02d}.blp").write_bytes(
                    render(tier, count, layer))
    print("Rendered 360 masked tier slices (Pattern, Border, Shadow, Relief, Halo)")
