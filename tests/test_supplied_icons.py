"""Validate converted user-provided wheel icons against the source artwork."""
from pathlib import Path
import runpy
import struct

root = Path(__file__).resolve().parents[1]
convert = runpy.run_path(str(root / "tools" / "import_user_icons.py"))
assert "Profession" not in convert["ICONS"], "replaced pack art must not be reused"
assert {"Back", "Cross", "General", "Herbalism", "mailbox",
        "ProfessionTrainer", "ProfessionVendor", "!Questmark", "Boat",
        "FlightMaster", "PadlockLocked", "PadlockUnlocked", "Portal",
        "QuestionQuestmark", "Travel", "Hearthstone", "Waypoint",
        "Settings", "Alchemy", "Favourites", "Fishing",
        "AlchemyTrainer", "BlacksmithingTrainer", "CookingTrainer",
        "FirstAidTrainer", "FishingTrainer", "HerbalismVendor",
        "EnchantmentTrainer", "EngineeringTrainer",
        "HerbalismTrainer", "LeatherworkingTraner",
        "MiningTrainer", "TailoringTrainer", "AlchemyVendor",
        "BlacksmithingVendor"} <= set(convert["ICONS"])
assert len(convert["CLASS_ICONS"]) == 13
assert convert["CLASS_ICONS"]["Rouge"] == "ClassRogue"
for source, target in convert["ICONS"].items():
    expected = convert["asset"](root / "art" / "wheel-icons" / f"{source}.png")
    observed = (root / "Textures" / f"{target}.blp").read_bytes()
    assert observed == expected, f"stale or corrupted {target} icon"
    assert struct.unpack_from("<4sI4BII", observed) == (b"BLP2", 1, 3, 8, 8, 0, 256, 256)
    pixels = observed[1172:]
    assert any(pixels[3::4]) and any(alpha == 0 for alpha in pixels[3::4])
    assert (root / "Textures" / f"Soft{target}.blp").read_bytes() == convert["soft_asset"](observed)
for source, target in convert["CLASS_ICONS"].items():
    expected = convert["asset"](root / "art" / "class-trainers" / f"{source}.png")
    assert (root / "Textures" / f"{target}.blp").read_bytes() == expected
    assert (root / "Textures" / f"Soft{target}.blp").read_bytes() == convert["soft_asset"](expected)
for service in ("Vendor", "Travel", "Favorites", "Quests"):
    original = (root / "Textures" / f"Service{service}.blp").read_bytes()
    assert (root / "Textures" / f"SoftService{service}.blp").read_bytes() == convert["soft_asset"](original)
logo = (root / "Textures" / "PackLogo.blp").read_bytes()
assert logo == convert["logo"](root / "art" / "wheel-icons" / "All.png")
assert logo[1172 + 3] == 0 and logo[1172 + (128 * 256 + 128) * 4 + 3] > 0
print(f"{len(convert['ICONS'])} wheel icons, {len(convert['CLASS_ICONS'])} class icons and provisional compass byte-verified")
