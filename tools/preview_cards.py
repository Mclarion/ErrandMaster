"""Offline approximation of compact translucent scrolling targets; not a client capture."""
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.testdeps/target-card-preview.png'

def asset(name):
    data = (ROOT / 'Textures' / f'{name}.blp').read_bytes()
    _, _, _, _, _, _, w, h = struct.unpack_from('<4sI4BII', data)
    return Image.frombytes('RGBA', (w, h), data[struct.unpack_from('<I', data, 20)[0]:], 'raw', 'BGRA')

pattern, gold = asset('CardPattern'), asset('CardFrame')
canvas = Image.new('RGBA', (700, 520), (32, 47, 59, 255))
draw = ImageDraw.Draw(canvas)
for y in range(0, 520, 32):
    draw.line((0,y,700,y),fill=(40,58,66))
for x in range(0, 700, 32):
    draw.line((x,0,x,520),fill=(40,58,66))
shell=Image.new('RGBA',canvas.size,(0,0,0,0))
ImageDraw.Draw(shell).rounded_rectangle((20,20,320,360),radius=8,fill=(9,16,22,45))
canvas.alpha_composite(shell)
font = ImageFont.truetype('DejaVuSans.ttf', 11)
bold = ImageFont.truetype('DejaVuSans-Bold.ttf', 12)
draw.text((31,28),'TARGETS',font=bold,fill=(227,196,137))
entries = [
    ('Ammo Vendor - Unknown Location',(8,190,120)),
    ('Bank - 1233 yd - Dun Morogh - Unknown Path',(40,112,255)),
    ('Repair - 340 yd - Observed Path',(238,48,48)),
    ('Trainer - Ironforge - Unknown Path',(0,189,213)),
    ('Waypoint - ~80 yd direct - Unknown Path',(225,170,0)),
    ('Mailbox - Unknown Location',(238,137,0)),
    ('Seventh target (scroll to see more)',(138,93,209)),
]
for index,(text,tint) in enumerate(entries):
    x,y = 28,44+58*index
    if y+54>340: continue
    layer = pattern.resize((266,54),Image.Resampling.LANCZOS)
    colored=Image.blend(layer,Image.new('RGBA',layer.size,tint+(255,)),.48)
    colored.putalpha(layer.getchannel('A').point(lambda a: round(a*.48)))
    canvas.alpha_composite(colored,(x,y))
    frame=gold.resize((266,54),Image.Resampling.LANCZOS)
    frame.putalpha(frame.getchannel('A').point(lambda a: round(a*.8)))
    canvas.alpha_composite(frame,(x,y))
    d=ImageDraw.Draw(canvas)
    words,lines,line=text.split(),[],''
    for word in words:
        candidate=f'{line} {word}'.strip()
        if line and d.textlength(candidate,font=font)>205:
            lines.append(line); line=word
        else: line=candidate
    lines.append(line)
    for j,value in enumerate(lines[:2]):
        d.text((x+10,y+9+j*16),value,font=font,fill=(246,241,227),stroke_width=1,stroke_fill=(20,22,25))
    for j,glyph in enumerate(('×','☆','➤')):
        d.text((x+246,y+4+j*16),glyph,font=bold,fill=(230,206,158))
draw=ImageDraw.Draw(canvas)
draw.rounded_rectangle((302,48,308,337),radius=3,fill=(31,43,49,150))
draw.rounded_rectangle((302,48,308,157),radius=3,fill=(192,167,110,210))
draw.text((343,42),'OFFLINE MOCK / NOT A CLIENT CAPTURE',font=bold,fill=(225,197,154))
OUT.parent.mkdir(parents=True,exist_ok=True)
canvas.convert('RGB').save(OUT)
print(OUT)
