"""Generate antialiased, self-contained WoW service icons."""
from pathlib import Path
from PIL import Image, ImageDraw
import struct

ROOT = Path(__file__).resolve().parents[1] / "Textures"
S = 512
INK = (239, 225, 189, 255)
ART = {
    "Repair": [("line", [(170, 352), (320, 182)], 40), ("line", [(252, 156), (350, 252)], 54)],
    "Auction": [("line", [(165, 208), (337, 345)], 48), ("line", [(285, 130), (367, 205)], 56), ("line", [(130, 378), (382, 378)], 22)],
    "Mail": [("rect", (122, 184, 390, 332), 24), ("line", [(130, 193), (256, 279), (382, 193)], 18)],
    "Vendor": [("ellipse", (166, 146, 346, 326), 22), ("line", [(154, 374), (358, 374)], 25)],
    "Custom": [("ellipse", (172, 125, 340, 293), 24), ("line", [(256, 293), (256, 404)], 24)],
    "Trainer": [("line", [(126, 185), (256, 228), (386, 185)], 24), ("line", [(126, 185), (126, 353), (256, 392), (386, 353), (386, 185)], 22)],
    "Travel": [("line", [(110, 195), (256, 315), (402, 195)], 27),
               ("line", [(256, 315), (256, 392)], 24),
               ("line", [(115, 215), (169, 330), (230, 313)], 20),
               ("line", [(397, 215), (343, 330), (282, 313)], 20)],
    "Quests": [("rect", (169, 139, 340, 376), 22),
               ("line", [(198, 223), (307, 223)], 20),
               ("line", [(198, 287), (278, 287)], 20)],
    "Skills": [("line", [(256, 131), (256, 382)], 24),
               ("line", [(132, 255), (380, 255)], 24),
               ("line", [(168, 168), (344, 344)], 20),
               ("line", [(344, 168), (168, 344)], 20)],
    "Items": [("ellipse", (161, 142, 351, 246), 22),
              ("line", [(164, 212), (131, 356), (382, 356), (349, 212)], 24)],
    "Flight": [("line", [(105, 175), (256, 321), (407, 175)], 26),
               ("line", [(125, 210), (176, 327), (256, 350), (336, 327), (387, 210)], 22)],
    "Portal": [("ellipse", (148, 108, 364, 404), 32),
               ("ellipse", (196, 174, 316, 352), 26)],
    "Boat": [("line", [(110, 324), (158, 377), (352, 377), (402, 324), (110, 324)], 25),
             ("line", [(256, 131), (256, 321)], 24),
             ("line", [(255, 152), (357, 288), (255, 288)], 22)],
    "Hearthstone": [("ellipse", (156, 139, 356, 377), 28),
                    ("line", [(178, 265), (239, 208), (300, 263), (249, 321)], 24)],
    "Favorites": [("line", [(256, 122), (293, 220), (399, 224), (319, 290),
                             (344, 392), (256, 334), (168, 392), (193, 290),
                             (113, 224), (219, 220), (256, 122)], 20)],
    "Lock": [], "Unlock": [],
}

TILE = {"Repair": (111, 44, 45), "Auction": (84, 55, 119),
        "Mail": (145, 99, 40), "Vendor": (52, 111, 59),
        "Trainer": (43, 80, 126), "Travel": (153, 113, 44),
        "Quests": (153, 113, 44), "Skills": (39, 110, 115),
        "Items": (107, 78, 47), "Flight": (153, 113, 44),
        "Portal": (153, 113, 44), "Boat": (153, 113, 44),
        "Hearthstone": (153, 113, 44), "Custom": (126, 48, 113),
        "Favorites": (126, 48, 113)}

def asset(name):
    image = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(image)
    tint = TILE.get(name, (27, 42, 56))
    d.ellipse((45, 45, 467, 467), fill=(*tint, 236),
              outline=(219, 178, 91, 220), width=18)
    if name in ("Lock", "Unlock"):
        x = 0 if name == "Lock" else 32
        d.arc((184+x, 130, 328+x, 310), 180, 360, fill=INK, width=28)
        d.line(((184+x, 220), (184+x, 283)), fill=INK, width=28)
        if name == "Lock":
            d.line(((328, 220), (328, 283)), fill=INK, width=28)
        d.rounded_rectangle((174, 265, 338, 381), radius=18, fill=INK)
    for kind, points, width in ART[name]:
        getattr(d, "rectangle" if kind == "rect" else kind)(points, outline=INK, width=width) if kind != "line" else d.line(points, fill=INK, width=width, joint="curve")
    image = image.resize((128, 128), Image.Resampling.LANCZOS)
    raw = image.tobytes()
    header = struct.pack("<4sI4BII", b"BLP2", 1, 3, 8, 8, 0, 128, 128)
    header += struct.pack("<16I", 1172, *([0] * 15))
    header += struct.pack("<16I", len(raw), *([0] * 15)) + bytes(1024)
    return header + raw

if __name__ == "__main__":
    for name in ART:
        (ROOT / f"Service{name}.blp").write_bytes(asset(name))
    print(f"Rendered {len(ART)} service icons")
