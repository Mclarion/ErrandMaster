"""Convert the user's transparent wheel art to standalone WoW BLP2 icons.

Run after copying newly supplied source PNGs into art/wheel-icons. The composite
All.png catalog is reference-only and must never become a runtime icon.
"""
from pathlib import Path
import struct
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art" / "wheel-icons"
TARGET = ROOT / "Textures"
ICONS = {
    "Bank": "PackBank",
    "AuctionHouse": "PackAuctionHouse",
    "Repair": "PackRepair",
    "Guild": "PackGuild",
    "Ammo": "PackAmmo",
    "Blacksmith": "PackBlacksmith",
    "Food": "PackFood",
    "reagents": "PackReagents",
    "Back": "PackBack",
    "Cross": "PackCross",
    "General": "PackGeneral",
    "Herbalism": "PackHerbalism",
    "mailbox": "PackMailbox",
    "ProfessionTrainer": "PackProfessionTrainer",
    "ProfessionVendor": "PackProfessionVendor",
    "!Questmark": "PackQuestmark",
    "Boat": "PackBoat",
    "FlightMaster": "PackFlightMaster",
    "PadlockLocked": "PackPadlockLocked",
    "PadlockUnlocked": "PackPadlockUnlocked",
    "Portal": "PackPortal",
    "QuestionQuestmark": "PackQuestionQuestmark",
    "Travel": "PackTravel",
    "Hearthstone": "PackHearthstone",
    "Waypoint": "PackWaypoint",
    "Settings": "PackSettings",
    "Alchemy": "PackAlchemy",
    "Favourites": "PackFavourites",
    "Fishing": "PackFishing",
    "AlchemyTrainer": "PackAlchemyTrainer",
    "BlacksmithingTrainer": "PackBlacksmithingTrainer",
    "CookingTrainer": "PackCookingTrainer",
    "FirstAidTrainer": "PackFirstAidTrainer",
    "FishingTrainer": "PackFishingTrainer",
    "HerbalismVendor": "PackHerbalismVendor",
    "EnchantmentTrainer": "PackEnchantmentTrainer",
    "EngineeringTrainer": "PackEngineeringTrainer",
    "HerbalismTrainer": "PackHerbalismTrainer",
    "LeatherworkingTraner": "PackLeatherworkingTrainer",
    "MiningTrainer": "PackMiningTrainer",
    "TailoringTrainer": "PackTailoringTrainer",
    "AlchemyVendor": "PackAlchemyVendor",
    "BlacksmithingVendor": "PackBlacksmithingVendor",
}
CLASS_ICONS = {
    name: "Class" + ("Rogue" if name == "Rouge" else name)
    for name in ("DeathKnight", "DemonHunter", "Druid", "Evoker", "Hunter",
                 "Mage", "Monk", "Paladin", "Priest", "Rouge", "Shaman",
                 "Warlock", "Warrior")
}
SIZE = 256


def blp(rgba: Image.Image) -> bytes:
    raw = rgba.tobytes()
    header = struct.pack("<4sI4BII", b"BLP2", 1, 3, 8, 8, 0, SIZE, SIZE)
    header += struct.pack("<16I", 1172, *([0] * 15))
    header += struct.pack("<16I", len(raw), *([0] * 15)) + bytes(1024)
    return header + raw


def asset(path: Path) -> bytes:
    with Image.open(path) as image:
        if not (64 <= min(image.size) and max(image.size) <= 4096):
            raise ValueError(f"wheel icon must be bounded: {path}")
        rgba = image.convert("RGBA")
        minimum, maximum = rgba.getchannel("A").getextrema()
        if minimum != 0 or maximum != 255:
            raise ValueError(f"wheel icon must have transparent edges and visible art: {path}")
        scale = SIZE / max(rgba.size)
        fitted = rgba.resize((round(rgba.width * scale), round(rgba.height * scale)),
                             Image.Resampling.LANCZOS)
        rgba = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        rgba.alpha_composite(fitted, ((SIZE - fitted.width) // 2,
                                      (SIZE - fitted.height) // 2))
    return blp(rgba)


def soft_asset(data: bytes) -> bytes:
    """Pre-blur static art for inactive, visually recessed menu tiers."""
    magic, kind, compression, alpha, alpha_kind, mipmaps, width, height = (
        struct.unpack_from("<4sI4BII", data))
    if (magic, kind, compression, alpha, alpha_kind, mipmaps) != (
            b"BLP2", 1, 3, 8, 8, 0) or width not in (128, 256) or height != width:
        raise ValueError("expected an uncompressed RGBA wheel icon")
    offset = struct.unpack_from("<I", data, 20)[0]
    length = struct.unpack_from("<I", data, 84)[0]
    if offset != 1172 or length != width * height * 4 or len(data) != offset + length:
        raise ValueError("invalid BLP pixel payload")
    image = Image.frombytes("RGBA", (width, height), data[offset:])
    image = image.filter(ImageFilter.GaussianBlur(width * .075))
    return blp(image.resize((SIZE, SIZE), Image.Resampling.LANCZOS))


def logo(path: Path) -> bytes:
    """Isolate the source catalog's compass; no unrelated sheet panels or labels."""
    with Image.open(path) as image:
        if image.size != (1536, 1024):
            raise ValueError("the compass crop needs review for a changed catalog")
        rgba = image.convert("RGBA").crop((16, 0, 128, 112)).resize(
            (SIZE, SIZE), Image.Resampling.LANCZOS)
    # Preserve the dark *inside* the compass rim, not the dark catalog sheet.
    disc = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(disc).ellipse((36, 44, 218, 230), fill=255)
    points = rgba.convert("RGB").convert("L").point(
        lambda value: 255 if value > 80 else 0)
    points = points.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1))
    mask = ImageChops.lighter(disc, points)
    # The catalog title starts just beyond the compass's east point.
    ImageDraw.Draw(mask).rectangle((241, 0, 255, 255), fill=0)
    rgba.putalpha(ImageChops.multiply(rgba.getchannel("A"), mask))
    return blp(rgba)


if __name__ == "__main__":
    for source, target in ICONS.items():
        data = asset(SOURCE / f"{source}.png")
        (TARGET / f"{target}.blp").write_bytes(data)
        (TARGET / f"Soft{target}.blp").write_bytes(soft_asset(data))
    for source, target in CLASS_ICONS.items():
        data = asset(ROOT / "art" / "class-trainers" / f"{source}.png")
        (TARGET / f"{target}.blp").write_bytes(data)
        (TARGET / f"Soft{target}.blp").write_bytes(soft_asset(data))
    data = logo(SOURCE / "All.png")
    (TARGET / "PackLogo.blp").write_bytes(data)
    (TARGET / "SoftPackLogo.blp").write_bytes(soft_asset(data))
    for path in TARGET.glob("Service*.blp"):
        (TARGET / f"Soft{path.name}").write_bytes(soft_asset(path.read_bytes()))
    print(f"Imported {len(ICONS)} wheel and {len(CLASS_ICONS)} class icons, plus the provisional compass")
