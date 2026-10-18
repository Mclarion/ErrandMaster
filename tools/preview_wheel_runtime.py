"""Render actual Lua wheel-region UVs/positions, not a second geometry model.
Offline software rasterization only; not proof of WoW rendering or input.
"""
from pathlib import Path
import struct
import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageOps

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.testdeps'))
from lupa.lua51 import LuaRuntime


def collect_regions(w, depth, get):
    regions = []
    history = get(w, 'historyViews')
    for level in range(1, depth):
        view = history[level]
        for key in ('shadows', 'sectors', 'reliefs', 'borders', 'iconGlows',
                    'medallionGlows', 'icons', 'halos', 'medallions'):
            for i in range(1, w['tiers'][level]['count']+1):
                regions.append(view[key][i])
    for key in ('shadow', 'sector', 'relief', 'glow', 'iconGlow', 'medallionGlow',
                'texture', 'borderGlow', 'medallion', 'activeMedallion'):
        for i in range(1, w['count']+1):
            regions.append(w['slots'][i][key])
    regions.extend((w['centerShadow'], w['centerArt'], w['centerPlate']))
    return regions


def render_scene(depth, large=False, hovered=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    f = lua.execute('return dofile("tests/wheel_fixture.lua")()')
    get = lua.eval('rawget')
    settings = f['addon']['db']['data']['settings']
    if large:
        settings['wheelRadius'], settings['wheelIconSize'], settings['wheelScale'] = 80, 72, 1.5
    f['root'](f)
    for _ in range(depth-1):
        f['click'](f, 4)
    w = f['wheel']
    if hovered:
        f['hit'](f,1)
        w['SetSelection'](w, 1)
        for _ in range(20):
            w['frame']['scripts']['OnUpdate'](w['frame'], .016)
    image = Image.new('RGBA', (600, 620), '#78826c')
    draw = ImageDraw.Draw(image)
    for y in range(0, 620, 28):
        draw.line((0, y, 600, y+110), fill='#566348', width=12)
    cx, cy = w['centerX'], w['centerY']

    def region(r):
        if r is None or not get(r, 'shown'):
            return
        path = get(r, 'texture')
        if not isinstance(path, str) or not path.endswith('.blp'):
            return
        data = (ROOT / 'Textures' / path.replace('\\', '/').split('/')[-1]).read_bytes()
        width, height = struct.unpack_from('<II', data, 12)
        src = Image.frombytes('RGBA', (width, height), data[1172:], 'raw', 'BGRA')
        if get(r, 'desaturated'):
            src = Image.merge('RGBA', (*([ImageOps.grayscale(src)]*3), src.getchannel('A')))
        size = max(1, round(r['w'])), max(1, round(r['h']))
        coords = get(r, 'uv')
        if coords is not None and len(coords) == 8:
            a = [coords[i] for i in range(1, 9)]
            affine = ((a[4]-a[0])*width/size[0], (a[2]-a[0])*width/size[1], a[0]*width,
                      (a[5]-a[1])*height/size[0], (a[3]-a[1])*height/size[1], a[1]*height)
            src = src.transform(size, Image.Transform.AFFINE, affine, Image.Resampling.BICUBIC)
        else:
            src = src.resize(size, Image.Resampling.LANCZOS)
        color = get(r, 'color')
        channels = list(src.split())
        if color is not None:
            for i in range(3):
                factor = color[i+1]
                channels[i] = channels[i].point(lambda p, k=factor: round(p*k))
        alpha = get(r, 'alpha')
        if alpha is not None:
            channels[3] = channels[3].point(lambda p: round(p*alpha))
        src = Image.merge('RGBA', channels)
        p = r['point']
        x, y = p[4]-cx+300, 620-(p[5]-cy+300)
        pos = (round(x-size[0]/2), round(y-size[1]/2))
        if get(r, 'blend') == 'ADD':
            light = Image.new('RGB',image.size)
            light.paste(src.convert('RGB'),pos,src.getchannel('A'))
            image.paste(ImageChops.add(image.convert('RGB'),light))
        else:
            image.alpha_composite(src, pos)

    regions = collect_regions(w, depth, get)
    layers={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3,'HIGHLIGHT':4}
    for r in sorted(regions,key=lambda r:(layers.get(get(r,'layer'),0),get(r,'sublevel') or 0)):
        region(r)
    text = w['centerLabel']['text']
    font = ImageFont.truetype('DejaVuSans.ttf', 12)
    if text:
        lines = []
        for word in text.split():
            candidate = (lines[-1]+' '+word) if lines else word
            if lines and draw.textlength(candidate, font=font) > w['centerLabel']['w']:
                lines.append(word)
            elif lines:
                lines[-1] = candidate
            else:
                lines.append(word)
        draw.multiline_text((300, 320), '\n'.join(lines), font=font, anchor='mm', align='center', fill='#fff2cd')
    title = f'{depth} tier(s) · '+('radius80 / icon72 / scale1.5' if large else 'defaults')
    draw.text((16, 16), title, fill='white', font=ImageFont.truetype('DejaVuSans.ttf', 16))
    draw.text((16, 585), f"Full extent {w['model']['extent']*2:.1f} UI units · software preview", fill='white', font=font)
    return image


if __name__ == '__main__':
    canvas = Image.new('RGBA', (1800, 620))
    for index, args in enumerate(((1, False, False), (3, False, True), (3, True, True))):
        canvas.alpha_composite(render_scene(*args), (index*600, 0))
    out = ROOT / '.testdeps/wheel-runtime-preview.png'
    canvas.convert('RGB').save(out)
    print(out)
