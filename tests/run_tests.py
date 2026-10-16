"""Parse the TOC and run addon tests with an actual Lua 5.1 runtime."""
from pathlib import Path
import sys
import runpy
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
runtime = LuaRuntime()
loadfile = runtime.eval("loadfile")
for path in [*paths, *sorted((ROOT / "tests").glob("*.lua"))]:
    loadfile(str(path))
print(f"TOC and syntax: {len(paths)} runtime Lua files")
for script in ("test_core.lua", "test_locations.lua", "test_npcs.lua", "test_discovery.lua", "test_smart_services.lua",
               "test_quests.lua", "test_quest_waypoints.lua", "test_walk_graph.lua", "test_trails.lua",
               "test_route_walk.lua", "test_npc_route.lua", "test_zone_search.lua",
               "test_taxi_advice.lua",
               "test_radial.lua", "test_wheel_editor.lua", "test_world_map.lua", "test_destinations.lua",
               "test_minimap.lua", "test_boot.lua"):
    LuaRuntime().execute(f'dofile("tests/{script}")')
