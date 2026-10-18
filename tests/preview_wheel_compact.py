"""Legacy entry point; canonical preview now reads actual Lua region geometry."""
if __name__ == '__main__':
    import runpy
    runpy.run_path('tools/preview_wheel_runtime.py', run_name='__main__')
    raise SystemExit
from math import cos, pi, sin, sqrt
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'.testdeps'/'wheel-compact-preview.png'
canvas=Image.new('RGBA',(1200,650),'#161d27')
font=ImageFont.truetype('DejaVuSans.ttf',14)
font_big=ImageFont.truetype('DejaVuSans-Bold.ttf',20)
font_hub=ImageFont.truetype('DejaVuSans-Bold.ttf',14)

def blp(name):
    data=(ROOT/'Textures'/f'{name}.blp').read_bytes()
    assert data[:4]==b'BLP2'
    width,height=struct.unpack_from('<II',data,12)
    return Image.frombytes('RGBA',(width,height),data[1172:],'raw','BGRA')

def place(name,x,y,diameter,angle=0,tint=None,rotated=False):
    image=blp(name)
    if tint:
        r,g,b,a=image.split()
        image=Image.merge('RGBA',(r.point(lambda v: round(v*tint[0]/255)),
            g.point(lambda v: round(v*tint[1]/255)),
            b.point(lambda v: round(v*tint[2]/255)),a))
    # WoW SetRotation samples the source with 1/sqrt(2) scaling, hence
    # a full-disk widget must have diameter 2*radius*sqrt(2).
    size=round(diameter/sqrt(2)) if rotated else round(diameter)
    image=image.resize((size,size),Image.Resampling.LANCZOS)
    if rotated: image=image.rotate(angle*180/pi,resample=Image.Resampling.BICUBIC)
    canvas.alpha_composite(image,(round(x-size/2),round(y-size/2)))

blue=(55,99,197);green=(24,173,109);purple=(168,90,202)
gold=(217,155,51);red=(202,68,68)
roots=[('Bank','PackBank',blue),('Auction House','PackAuctionHouse',purple),
 ('Repair','PackRepair',red),('Vendor','PackProfessionVendor',green),
 ('Mailbox','PackMailbox',gold),('Trainer','PackProfessionTrainer',blue),
 ('Travel','PackTravel',gold),('Custom','PackSettings',purple),
 ('Quests','PackQuestmark',gold),('Skills','ServiceSkills',blue),
 ('Items','ServiceItems',gold)]
vendors=[('Food','PackFood',red),('Reagents','PackReagents',purple),
 ('Ammo','PackAmmo',gold),('Profession','PackProfessionVendor',green),
 ('General Goods','PackGeneral',green),('Back','PackBack',gold)]

def wheel(cx,cy,radius,entries,depth=0,center=pi/2,selected=None):
    count=len(entries)
    sweep=2*pi if depth==0 else min(5.5,max(pi/2,count*.42))
    inner=radius*(.28 if depth==0 else .70)
    angles=[pi/2-2*pi*i/count if depth==0 else
            center+sweep/2-(i+.5)*sweep/count for i in range(count)]
    for index,(_,_,color) in enumerate(entries):
        angle=angles[index]
        for layer in ('Pattern','Border'):
            place(f'Wheel{layer}T{depth}N{count:02}',cx,cy,2*radius*sqrt(2),
                  angle-pi/2,color if layer=='Pattern' else None,True)
    for index,(name,icon,color) in enumerate(entries):
        angle=angles[index]
        rr=(radius+inner)/2
        px,py=cx+rr*cos(angle),cy-rr*sin(angle)
        icon_size=min(40,(radius-inner)*.7,rr*sweep/count*.74)
        place(icon,px,py,icon_size)
        jewel=('Green' if color==green else 'Blue' if color==blue else
               'Red' if color==red else 'Purple' if color==purple else 'Yellow')
        mr=radius
        # Supplied medallions have .70 inset within their square.
        size=min(30,max(14,radius*sweep/count*.3))
        place(f'Medallion{jewel}{"Active" if index==selected else "Inactive"}',
              cx+mr*cos(angle),cy-mr*sin(angle),size*sqrt(2)/.70,
              angle+pi/2,rotated=True)
    return angles

angles=wheel(244,300,118,roots,selected=3)
place('WheelCenter',244,300,118*.55)
pen=ImageDraw.Draw(canvas)
pen.text((30,28),'Compact root · 118 UI px radius',font=font_big,fill='#f4dbad')
angles2=wheel(770,300,128,roots,selected=3)
wheel(770,300,128/.70,vendors,1,angles2[3],selected=3)
place('WheelCenterHover',770,300,160)
pen.text((770,300),'Blacksmithing\nTrainer',font=font_hub,anchor='mm',align='center',
         spacing=4,fill='#eee0c0')
pen.text((583,28),'Attached 2-tier wheel · root + vendor',font=font_big,fill='#f4dbad')
pen.text((30,617),'Offline approximation; verify texture rotation sign, medallion orientation and UI scale in WoW.',
         font=font,fill='#c1b8a7')
OUT.parent.mkdir(exist_ok=True)
canvas.convert('RGB').save(OUT)
print(OUT)
