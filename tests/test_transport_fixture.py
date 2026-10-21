"""Local-only pinned SPF transport fixture extraction contracts."""
import hashlib
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools/prepare_transport_fixture.py'
SOURCE = ROOT / '.testdeps/transport-source'
ROUTES_SHA = 'f582d1d7d783275738c49ec03df01ee9b3a42fe21db72c1a132b4e1144a999a3'
PORTALS_SHA = '9f1241828e387b3915a07d9999cd26c9b70cf6e4110e802a80be37ac907a8c36'


class TransportFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / '.testdeps')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / 'source'
        self.source.mkdir()
        for name in ('Data_Routes.lua', 'Data_Portals.lua'):
            shutil.copyfile(SOURCE / name, self.source / name)
        self.out = self.base / 'fixture.lua'

    def run_tool(self):
        return subprocess.run([sys.executable, str(SCRIPT), '--source-dir', str(self.source),
                               '--output', str(self.out)], cwd=ROOT, capture_output=True, text=True)

    def test_pinned_extraction_is_deterministic_and_adapter_compatible(self):
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        data = self.out.read_bytes()
        self.assertEqual(self.run_tool().returncode, 0)
        self.assertEqual(self.out.read_bytes(), data)
        text = data.decode()
        self.assertIn('addon.transportData', text)
        self.assertIn(ROUTES_SHA, text)
        self.assertIn(PORTALS_SHA, text)
        self.assertIn('01559975bff0320a9fd2be496a774e20978aa807', text)
        self.assertNotIn('walk =', text)
        self.assertNotIn('frames =', text)
        self.assertNotIn('arrive =', text)
        self.assertNotIn('depart =', text)
        self.assertNotIn('period =', text)
        self.assertNotIn('passage', text.lower())
        self.assertNotIn('Entrances', text)
        self.assertNotIn('zeppelin', text)
        self.assertIn('AreaTrigger 527', text)
        self.assertIn('AreaTrigger 542', text)
        self.assertIn(ROUTES_SHA, result.stdout)
        self.assertIn(PORTALS_SHA, result.stdout)
        self.assertIn('routes=8 docks=15 portals=2', result.stdout)
        script = '''
local addon = {}
assert(loadfile(arg[1]))('ErrandMaster', addon)
assert(loadfile('Data/StaticTransport.lua'))('ErrandMaster', addon)
local d = addon.transportData
local n, docks, portals = 0, 0, 0
for id,r in pairs(d.Routes) do
  n=n+1; assert(r.kind=='boat' and #r.stops>=2)
  for _,s in ipairs(r.stops) do
    assert(d.Docks[s.dock]); assert(not s.arrive and not s.depart)
  end
end
for _,dock in pairs(d.Docks) do docks=docks+1; assert(not dock.walk) end
for _,p in ipairs(d.Portals) do
  portals=portals+1; assert(p.kind=='portal' and p.name and p.from and p.to and p.provenance)
end
assert(n==8 and docks==15 and portals==2)
assert(addon.staticTransport:Build() == nil)
assert(#addon.staticTransport.index.Boat[0] > 0)
-- Exercise native projection with synthetic API geometry over REAL source
-- records. This validates the adapter, not the client's actual coordinates.
CreateVector2D=function(x,y) return {GetXY=function() return x,y end} end
UnitFactionGroup=function() return 'Alliance' end
C_Map={GetWorldPosFromMapPos=function(map) return map-10000,CreateVector2D(0,0) end,
 GetMapPosFromWorldPos=function(instance,point,map)
   local x,y=point:GetXY()
   return map or instance+10000,CreateVector2D(.5+x/100000,.5+y/100000)
 end}
local selected=0
for _,map in ipairs(addon.staticTransport:CandidateMaps('Portal')) do
  for _,entry in ipairs(addon.staticTransport:LocationsOnMap(map,'Portal')) do
    selected=selected+1
    assert(entry.endpoint=='from' and entry.x>=0 and entry.x<=1)
  end
end
assert(selected==2,'only the two real source portal entrances are candidates')
'''
        if shutil.which('lua'):
            check = subprocess.run(['lua', '-', str(self.out)], input=script,
                                   cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(check.returncode, 0, check.stderr)
        else:
            from lupa.lua51 import LuaRuntime
            runtime = LuaRuntime()
            runtime.globals().fixture_path = str(self.out)
            runtime.execute(script.replace('arg[1]', 'fixture_path'))

    def test_missing_input_fails_without_creating_output(self):
        (self.source / 'Data_Portals.lua').unlink()
        result = self.run_tool()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Data_Portals.lua', result.stderr)
        self.assertFalse(self.out.exists())

    def test_tampered_input_fails_closed_and_preserves_existing_output(self):
        self.assertEqual(self.run_tool().returncode, 0)
        before = self.out.read_bytes()
        with (self.source / 'Data_Routes.lua').open('ab') as file:
            file.write(b'\n-- malicious or accidental change\n')
        result = self.run_tool()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SHA256', result.stderr)
        self.assertEqual(self.out.read_bytes(), before)

    def test_unknown_lua_is_not_executed(self):
        spec = importlib.util.spec_from_file_location('transport_fixture', SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with self.assertRaises(ValueError):
            module.parse_lua('ns.Docks = { os.execute("touch /tmp/unsafe") }', 'Data_Routes.lua')


if __name__ == '__main__':
    unittest.main()
