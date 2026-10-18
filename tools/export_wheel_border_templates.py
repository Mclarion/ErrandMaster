"""Export authoring masks and exact per-count border specifications."""
from pathlib import Path
import csv
import io
import math
import runpy
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
art = runpy.run_path(str(ROOT / 'tools/render_ring_art.py'))
OUT = ROOT / '.testdeps/wheel-border-templates'
OUT.mkdir(parents=True, exist_ok=True)
rows = []
for tier in range(3):
    for count in range(1, 25):
        data = art['render'](tier, count, 'Pattern')
        mask = Image.frombytes('RGBA', (512, 512), data[1172:], 'raw', 'BGRA').getchannel('A')
        guide = Image.new('RGBA', (512, 512), (255, 255, 255, 0))
        guide.putalpha(mask)
        name = f'T{tier}-N{count:02d}-mask.png'
        guide.save(OUT / name)
        arc = math.degrees(art['sweep'](count, tier))
        inner = (0.42, 0.70, 0.74)[tier]
        rows.append(dict(file=name, tier=tier, count=count, canvas=512,
                         center_x=256, center_y=256, outer_radius_px=248,
                         inner_radius_px=round(248*inner, 6),
                         sector_angle_degrees=round(arc/count, 9),
                         full_arc_degrees=round(arc, 9),
                         half_angle_degrees=round(arc/count/2, 9)))
with (OUT / 'dimensions.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=rows[0])
    writer.writeheader()
    writer.writerows(rows)
text = '''# ErrandMaster border artwork contract — UV renderer

Author one transparent 512 × 512 RGBA PNG per desired T/N combination.
Center is (256,256); source outer radius is 248 pixels. Keep the outer
8-pixel perimeter transparent: it prevents edge streaks during UV rotation.
Masks are white guides ONLY, not final border art. Paint inside their alpha.
Leave the sector interior transparent: the supplied BackgroundPattern is a
separate nearly opaque, category-tinted layer. Border artwork stays untinted.
Do not bake icons, crystals, labels, emblem, or category fills into borders.

T0: root ring. Inner radius = 0.42 × outer radius.
T1: first child ring. Inner radius = 0.70 × outer radius.
T2: second and deeper child rings. Inner radius = 0.74 × outer radius.
Every source wedge points up (12 o'clock), symmetric about x=256.
Counts 1–24 are supplied for every tier family; back buttons count as entries.
Exact inner radii, sector angles and arc spans are in dimensions.csv.
Root sector angle = 360 / count degrees.
Child arc = min(5.5, max(pi/2, count*0.42)) radians; divide by count for a wedge.

Runtime scales these masks; no monitor-resolution-specific artwork is needed.
Displayed texture width = 2 × runtime outer radius / (248/256).
The entire menu, including ornament clearance, fits within the smaller of
520 UI units or 62% of the shorter viewport dimension. WoW UI scale then
converts UI units to physical pixels. Parent and child annuli share a center
and a radial boundary. Sparse children deliberately occupy partial arcs.
The hub emblem fits exactly in the root hole; crystals remain separate and
point inward. These dimensions define the current test candidate, not an
in-client visual approval. Confirm the next test before commissioning all 72.
'''
(OUT / 'README.txt').write_text(text)
archive = ROOT / '.testdeps/ErrandMaster-border-templates.zip'
with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
    for path in sorted(OUT.iterdir()):
        z.write(path, 'ErrandMaster-border-templates/'+path.name)
with ZipFile(archive) as z:
    assert z.testzip() is None and len(z.namelist()) == 74
print(f'Exported {len(rows)} authoring masks plus CSV/readme: {archive}')
