"""Measure the circular rim, not the decoration-biased opacity centroid."""
from pathlib import Path
import struct
from PIL import Image
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
data = (root / 'Textures/WheelCenter.blp').read_bytes()
w, h = struct.unpack_from('<II', data, 12)
a = Image.frombytes('RGBA', (w, h), data[1172:1172+w*h*4], 'raw', 'BGRA').getchannel('A')
rows = []
for y in range(h//4, round(h*.918)):
    xs = [x for x in range(w) if a.getpixel((x,y)) >= 200]
    if xs:
        rows.append((y, (xs[-1]-xs[0])/2, (xs[-1]+xs[0])/2))
mean_y = sum(y for y,_,_ in rows)/len(rows)
mean_z = sum(r*r+y*y for y,r,_ in rows)/len(rows)
cy = sum((y-mean_y)*(r*r+y*y-mean_z) for y,r,_ in rows) / sum((y-mean_y)**2 for y,_,_ in rows) / 2
cx = sum(x for _,_,x in rows)/len(rows)
for scale in (.75, 1, 1.5):
    lua = LuaRuntime(unpack_returned_tuples=True)
    f = lua.execute('return dofile("tests/wheel_fixture.lua")()')
    f['addon']['db']['data']['settings']['wheelScale'] = scale
    f['root'](f)
    wheel = f['wheel']; art = wheel['centerArt']; size = art['w']
    dx = art['point'][4]-wheel['centerX'] + (cx+.5-w/2)/w*size
    dy = art['point'][5]-wheel['centerY'] - (cy+.5-h/2)/h*size
    assert abs(dx)<.3 and abs(dy)<.3, (scale, dx, dy, 'hub rim must align with wheel center')
    aperture = wheel['tiers'][1]['innerRadius']
    for y in range(h):
        for x in range(w):
            if a.getpixel((x,y)) >= 32:
                px = art['point'][4]-wheel['centerX']+(x+.5-w/2)/w*size
                py = art['point'][5]-wheel['centerY']-(y+.5-h/2)/h*size
                assert px*px+py*py <= aperture*aperture, 'visible art must remain inside hub aperture'
print('hub rim aligned and visible artwork contained across scales')
