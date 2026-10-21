"""Parse the TOC and run addon tests with an actual Lua 5.1 runtime."""
from pathlib import Path
import sys
import runpy
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".testdeps"))
from lupa.lua51 import LuaRuntime

paths = []
for line in (ROOT / "ErrandMaster.toc").read_text().splitlines():
    line = line.strip()
    if line and not line.startswith("#"):
        target = ROOT / line.replace("\\", "/")
        assert target.is_file(), f"Missing TOC entry: {line}"
        paths.append(target)
assert paths[-1].name == "Init.lua", "Init.lua must load last"
assert "## Dependencies: QuestieDB" in (ROOT / "ErrandMaster.toc").read_text(), "NPC provider must be required"
assert len(paths) == len(set(paths)), "Duplicate TOC entry"
assert not any(path.name == "Bindings.xml" for path in paths), "Bindings.xml is auto-loaded"
bindings = ET.parse(ROOT / "Bindings.xml").getroot()
assert bindings.tag == "Bindings" and len(bindings) == 1
binding = bindings[0]
assert binding.get("name") == "ERRANDMASTER_WHEEL"
assert binding.get("category") == "ADDONS"
assert "ErrandMaster_OpenWheel()" in (binding.text or "")
runpy.run_path(str(ROOT / "tests" / "test_cursor_asset.py"))
runpy.run_path(str(ROOT / "tests" / "test_icons.py"))
runpy.run_path(str(ROOT / "tests" / "test_supplied_icons.py"))
runpy.run_path(str(ROOT / "tests" / "test_wheel_art.py"))
runpy.run_path(str(ROOT / "tests" / "test_wheel_union_shadow.py"))
runpy.run_path(str(ROOT / "tests" / "test_nested_ring_art.py"))
runpy.run_path(str(ROOT / "tests" / "test_card_assets.py"))
runpy.run_path(str(ROOT / "tests" / "test_icon_backlights.py"))
runpy.run_path(str(ROOT / "tests" / "test_runtime_preview.py"))
runpy.run_path(str(ROOT / "tests" / "test_hub_alignment.py"))
runpy.run_path(str(ROOT / "tests" / "test_local_transport_boundary.py"))
runpy.run_path(str(ROOT / "tests" / "test_waypoint_ui_render.py"))
glow_tests = runpy.run_path(str(ROOT / "tests" / "test_wheel_icon_silhouette_glow.py"))
glow_suite = unittest.TestSuite(
    unittest.defaultTestLoader.loadTestsFromTestCase(value)
    for value in glow_tests.values()
    if isinstance(value, type) and issubclass(value, unittest.TestCase)
    and value is not unittest.TestCase
)
assert glow_suite.countTestCases() > 0, "silhouette tests were not loaded"
if not unittest.TextTestRunner().run(glow_suite).wasSuccessful():
    raise SystemExit(1)
runtime = LuaRuntime()
loadfile = runtime.eval("loadfile")
for path in [*paths, *sorted((ROOT / "tests").glob("*.lua"))]:
    loadfile(str(path))
print(f"TOC and syntax: {len(paths)} runtime Lua files")
for script in ("test_core.lua", "test_locations.lua", "test_npcs.lua", "test_npcs_inventory.lua", "test_npc_diagnostics.lua", "test_npc_normalization.lua", "test_npc_map_budget.lua", "test_discovery.lua", "test_smart_services.lua", "test_discovery_partial.lua",
               "test_quests.lua", "test_quest_waypoints.lua", "test_quest_native_tracker.lua", "test_quest_route_integration.lua", "test_quest_zone_inventory.lua", "test_walk_graph.lua", "test_trails.lua", "test_trail_world_zero.lua",
               "test_route_walk.lua", "test_npc_route.lua", "test_zone_search.lua",
               "test_route_sequence.lua", "test_route_global_candidates.lua",
               "test_taxi_advice.lua", "test_flight_distance_rule.lua", "test_transport_catalog.lua", "test_static_transport.lua", "test_route_static_transport.lua", "test_boat_trips.lua", "test_boat_integration.lua",
               "test_transport_candidate.lua", "test_wheel_transport_labels.lua", "test_wheel_transport_root_upright.lua",
               "test_travel_points.lua", "test_wheel_geometry.lua", "test_radial.lua", "test_wheel_hierarchy.lua", "test_wheel_editor.lua", "test_window_position.lua",
               "test_wheel_failure.lua", "test_wheel_render_contract.lua", "test_wheel_materials.lua", "test_wheel_border_glow.lua",
               "test_wheel_acceptance_20261017.lua", "test_wheel_complete_bundle.lua", "test_wheel_effect_acceptance.lua", "test_world_map.lua", "test_destinations.lua",
               "test_wheel_quest_zones.lua", "test_wheel_quest_migration.lua", "test_wheel_quest_live_api.lua",
               "test_wheel_quest_full_root_access.lua", "test_wheel_quest_deferred.lua", "test_wheel_travel_services.lua", "test_quest_review.lua", "test_taxi.lua", "test_taxi_integration.lua", "test_transport_persistence.lua", "test_taxi_timing.lua",
               "test_wheel_edit_lifecycle_regression.lua", "test_wheel_native_drop_regression.lua",
               "test_wheel_transfer.lua", "test_wheel_move_handlers.lua",
               "test_minimap.lua", "test_addon_settings.lua", "test_ui_preferences.lua",
               "test_navigation_follow.lua", "test_navigation_queue.lua", "test_navigation_projection.lua", "test_navigation_arrow.lua", "test_waypoint_ui.lua", "test_waypoint_ui_world_tracking.lua", "test_plan_refresh_cache.lua", "test_object_catalog.lua", "test_route_objects.lua", "test_boot.lua"):
    LuaRuntime().execute(f'dofile("tests/{script}")')
