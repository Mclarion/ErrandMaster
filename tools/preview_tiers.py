"""Approximate the three linked wheels offline; this is not Forever rendering."""
from math import cos, pi, sin
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / "Textures"
OUT = ROOT / ".testdeps" / "layered-wheel-preview.png"
canvas = Image.new("RGBA", (1130, 890), "#101b2b")
font = ImageFont.truetype("DejaVuSans.ttf", 14)
small = ImageFont.truetype("DejaVuSans.ttf", 11)
header = ImageFont.truetype("DejaVuSans-Bold.ttf", 17)


def load(name):
    data = (TEXTURES / (name + ".blp")).read_bytes()
    _, _, _, _, _, _, width, height = struct.unpack_from("<4sI4BII", data)
    offset = struct.unpack_from("<I", data, 20)[0]
    return Image.frombytes("RGBA", (width, height), data[offset:])


def draw_wheel(cx, cy, diameter, names, icons, colors, dim=False, selected=None):
    count = len(names)
    layer = Image.new("RGBA", canvas.size)
    for i, color in enumerate(colors):
        sector = load(f"WheelSector{count:02}")
        art = Image.new("RGBA", sector.size, color + (0,))
        art.putalpha(sector.getchannel("A").point(
            lambda a: round(a * (.13 if dim else .82 if selected == i else .55))))
        art = art.resize((diameter, diameter), Image.Resampling.LANCZOS)
        art = art.rotate(-360*i/count, Image.Resampling.BICUBIC)
        layer.alpha_composite(art, (cx-diameter//2, cy-diameter//2))
    trim = load(f"WheelTrim{count:02}").resize((diameter, diameter), Image.Resampling.LANCZOS)
    if dim:
        trim.putalpha(trim.getchannel("A").point(lambda a: round(a*.35)))
    layer.alpha_composite(trim, (cx-diameter//2, cy-diameter//2))
    hubsize = round(diameter*.31)
    hub = load("WheelCenter").resize((hubsize,hubsize), Image.Resampling.LANCZOS)
    layer.alpha_composite(hub, (cx-hubsize//2,cy-hubsize//2))
    pen = ImageDraw.Draw(layer)
    icon_radius = diameter*(.28 if not dim and count <= 3 else .37)
    for i, (name, icon) in enumerate(zip(names, icons)):
        a = pi/2 - 2*pi*i/count
        x, y = round(cx+icon_radius*cos(a)), round(cy-icon_radius*sin(a))
        picture = load(("Soft" if dim else "") + icon).resize(
            (27 if dim else 39,)*2,Image.Resampling.LANCZOS)
        if dim:
            picture.putalpha(picture.getchannel("A").point(lambda v: round(v*.55)))
        layer.alpha_composite(picture, (x-picture.width//2,y-picture.height//2-6))
        if not dim or count <= 6:
            pen.text((x,y+19),name,font=small if dim else font,
                     fill="#8f9ba8" if dim else "#fbebcf",anchor="mm",
                     stroke_width=1,stroke_fill="#111b29")
    if not dim:
        cross = load("PackCross").resize((38,38),Image.Resampling.LANCZOS)
        layer.alpha_composite(cross,(cx-19,cy-27))
    else:
        pen.text((cx,cy),"MAIN" if count==11 else "VENDOR",font=small,
                 fill="#b3a47c",anchor="mm")
    canvas.alpha_composite(layer)


root_names = ("Bank","Auction","Repair","Vendor","Mail","Trainer","Travel",
              "Custom","Quests","Skills","Items")
root_icons = ("PackBank","PackAuctionHouse","PackRepair","ServiceVendor",
              "PackMailbox","ServiceTrainer","PackTravel","ServiceCustom",
              "PackQuestmark","ServiceSkills","ServiceItems")
root_colors = ((89,140,227),(173,115,214),(214,69,71),(77,196,110),
               (241,161,69),(89,140,227),(241,191,74),(196,87,186),
               (241,191,74),(74,191,214),(173,120,69))
vendor_names = ("Food","Reagents","Ammo","Profession","General","Back")
vendor_icons = ("PackFood","PackReagents","PackAmmo","PackProfessionVendor",
                "PackGeneral","PackBack")
vendor_colors = ((214,69,71),(173,115,214),(173,120,69),(77,196,110),
                 (77,196,110),(170,190,205))
profession_names = ("Herbalism","Blacksmith","Back")
profession_icons = ("PackHerbalism","PackBlacksmith","PackBack")
profession_colors = ((77,196,110),(241,161,69),(170,190,205))
pen = ImageDraw.Draw(canvas)
pen.line(((365,300),(457,300)),fill="#b89455",width=4)
pen.line(((560,403),(584,487)),fill="#b89455",width=4)
pen.text((250,90),"ROOT",font=header,fill="#d4ad61",anchor="mm")
pen.text((560,105),"VENDOR",font=header,fill="#d4ad61",anchor="mm")
pen.text((860,452),"PROFESSION VENDOR",font=header,fill="#d4ad61",anchor="mm")
draw_wheel(250,300,230,root_names,root_icons,root_colors,dim=True)
draw_wheel(560,300,206,vendor_names,vendor_icons,vendor_colors,dim=True)
draw_wheel(620,624,274,profession_names,profession_icons,
           profession_colors,selected=0)
pen = ImageDraw.Draw(canvas)
pen.text((565,846),"Illustrative professions only · offline composition, not a WoW client capture",
         font=small,fill="#9ba9bb",anchor="mm")
OUT.parent.mkdir(exist_ok=True)
canvas.convert("RGB").save(OUT)
print(OUT)
