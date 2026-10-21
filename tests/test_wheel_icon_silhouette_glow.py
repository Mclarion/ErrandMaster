"""Contract for deterministic glyph-shaped wheel underlays (not sector plates)."""
from pathlib import Path
import sys
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import import_user_icons as icons
import generate_wheel_icon_glow as glow


class WheelIconGlowTests(unittest.TestCase):
    def test_render_manifest_matches_every_generated_asset_and_disk(self):
        lua = (ROOT / "UI/RadialMenu.lua").read_text()
        manifest = lua.split("local glowAssets={}", 1)[1].split("}) do", 1)[0]
        bases = set(" ".join(re.findall(r'"([A-Za-z ]+)"', manifest)).split())
        expected = {name[4:-4] for name in glow.sources()}
        self.assertEqual(bases, expected)
        self.assertEqual(len(bases), 82)
        for base in bases:
            with self.subTest(base=base):
                self.assertTrue((ROOT / "Textures" / f"{base}.blp").is_file())
                self.assertTrue((ROOT / "Textures" / f"Glow{base}.blp").is_file())
        self.assertNotIn("PackLogo", bases)

    def test_live_rendered_glow_references_exist_on_disk(self):
        sys.path.insert(0, str(ROOT / ".testdeps"))
        from lupa.lua51 import LuaRuntime

        runtime = LuaRuntime(unpack_returned_tuples=True)
        fixture = runtime.execute('return dofile("tests/wheel_fixture.lua")()')
        fixture['root'](fixture)
        fixture['click'](fixture, 3)
        wheel = fixture['wheel']
        active = [wheel['slots'][i]['iconGlow']['texture']
                  for i in range(1, wheel['count'] + 1)]
        parent = wheel['historyViews'][1]['iconGlows']
        retained = [parent[i]['texture']
                    for i in range(1, wheel['tiers'][1]['count'] + 1)]
        self.assertIn('GlowPackFood.blp', active[0])
        self.assertIn('GlowPackProfessionVendor.blp', retained[2])
        for texture in active + retained:
            with self.subTest(texture=texture):
                self.assertTrue(texture.startswith(r'Interface\AddOns\ErrandMaster\Textures\Glow'))
                self.assertTrue((ROOT / 'Textures' / texture.rsplit('\\', 1)[-1]).is_file())

    def test_every_supplied_icon_and_native_service_has_its_own_underlay(self):
        sources = glow.sources()
        expected = {f"Glow{target}.blp" for target in icons.ICONS.values()}
        expected |= {f"Glow{target}.blp" for target in icons.CLASS_ICONS.values()}
        expected |= {f"Glow{path.name}" for path in (ROOT / "Textures").glob("Service*.blp")}
        self.assertEqual(set(sources), expected)
        self.assertNotIn("GlowPackLogo.blp", sources)  # All.png is a catalog, not an icon
        self.assertEqual(sources["GlowPackQuestionQuestmark.blp"], icons.source_path("QuestionQuestmark"))
        self.assertEqual(sources["GlowPackQuestmark.blp"], icons.source_path("!Questmark"))
        self.assertEqual(sources["GlowClassRogue.blp"], ROOT / "art/class-trainers/Rouge.png")
        self.assertEqual(sources["GlowServiceQuests.blp"], ROOT / "Textures/ServiceQuests.blp")
        self.assertEqual(sources["GlowPackTailoringVendor.blp"], icons.source_path("TailoringVender"))

    def test_question_mark_underlay_tracks_silhouette_and_preserves_hole(self):
        image = glow.decode_blp(glow.render(icons.source_path("QuestionQuestmark")))
        alpha = image.getchannel("A")
        self.assertEqual(image.size, (256, 256))
        self.assertEqual(alpha.getpixel((0, 0)), 0)
        self.assertEqual(alpha.getpixel((255, 255)), 0)
        # Top bowl has a real open counter; it cannot be a rectangular fill.
        self.assertGreater(alpha.getpixel((84, 84)), 85)
        self.assertLess(alpha.getpixel((116, 84)), alpha.getpixel((84, 84)) // 2)
        self.assertEqual(alpha.getpixel((20, 84)), 0)
        self.assertGreater(alpha.getpixel((128, 24)), 0)

    def test_native_service_uses_its_own_alpha_and_blp_roundtrips(self):
        source = ROOT / "Textures/ServiceQuests.blp"
        blob = glow.render(source)
        actual = glow.decode_blp(blob)
        self.assertEqual(actual.size, (256, 256))
        self.assertEqual(actual.getpixel((0, 0))[3], 0)
        self.assertEqual(blob, glow.render(source))
        self.assertEqual(actual.getpixel((128, 128))[:3], (255, 255, 255))
        with self.assertRaises(ValueError):
            glow.decode_blp(blob[:-1])

    def test_every_committed_underlay_roundtrips_and_reproduces(self):
        for name, source in glow.sources().items():
            with self.subTest(name=name):
                expected = glow.render(source)
                self.assertEqual((ROOT / "Textures" / name).read_bytes(), expected)
                decoded = glow.decode_blp(expected)
                self.assertEqual(decoded.size, (256, 256))
                alpha = decoded.getchannel("A")
                self.assertIsNotNone(alpha.getbbox())
                self.assertEqual(alpha.getpixel((0, 0)), 0)
                self.assertEqual(alpha.getpixel((255, 255)), 0)

    def test_canonical_art_is_untouched_and_generated_assets_reproduce(self):
        path = icons.source_path("Repair")
        before = path.read_bytes()
        first = glow.render(path)
        self.assertEqual(first, glow.render(path))
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual((ROOT / "Textures/GlowPackRepair.blp").read_bytes(), first)
        self.assertGreater(glow.decode_blp(first).getchannel("A").getbbox()[2], 200)


if __name__ == "__main__":
    unittest.main()
