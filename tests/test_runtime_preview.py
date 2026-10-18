"""Ensure the software preview includes the real runtime material layers."""
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("wheel_preview", root / "tools/preview_wheel_runtime.py")
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
f = lua.execute('return dofile("tests/wheel_fixture.lua")()')
f['root'](f)
f['click'](f, 4)
w = f['wheel']
regions = preview.collect_regions(w, 2, lua.eval('rawget'))
equal = lua.eval('function(a,b) return a == b end')
def included(region):
    return any(equal(region, r) for r in regions)
for key in ('centerShadow', 'centerArt', 'centerPlate'):
    assert included(w[key]), key
for key in ('shadow', 'iconGlow', 'medallionGlow', 'texture', 'medallion', 'activeMedallion'):
    assert included(w['slots'][1][key]), key
for key in ('shadows', 'iconGlows', 'medallionGlows', 'icons', 'medallions'):
    assert included(w['historyViews'][1][key][1]), key
print('runtime preview includes active, retained and hub material layers')
