"""Legacy entry point; canonical preview now reads actual Lua region geometry."""
if __name__ == '__main__':
    import runpy
    runpy.run_path('tools/preview_wheel_runtime.py', run_name='__main__')
    raise SystemExit
from math import cos, pi, sin
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / "Textures"
OUT = ROOT / ".testdeps" / "nested-wheel-preview.png"
canvas = Image.new("RGBA", (1330, 960), "#171b20")
font = ImageFont.truetype("DejaVuSans.ttf", 14)
header = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
center = 480, 475


def blp(name):
    data = (TEXTURES / f"{name}.blp").read_bytes()
    _, _, _, _, _, _, width, height = struct.unpack_from("<4sI4BII", data)
    return Image.frombytes("RGBA", (width, height), data[1172:], "raw", "BGRA")


def layer_image(name, size, angle, color=None, alpha=1):
    image = blp(name)
    if color:
        red, green, blue = image.split()[:3]
        image = Image.merge("RGBA", (
            red.point(lambda v: round(v*color[0]/255)),
            green.point(lambda v: round(v*color[1]/255)),
            blue.point(lambda v: round(v*color[2]/255)), image.getchannel("A")))
    if alpha != 1:
        image.putalpha(image.getchannel("A").point(lambda v: round(v*alpha)))
    return image.resize((round(size), round(size)), Image.Resampling.LANCZOS).rotate(
        (angle-pi/2)*180/pi, resample=Image.Resampling.BICUBIC)


def wrap(text, width):
    pen = ImageDraw.Draw(canvas)
    lines = []
    for word in text.split():
        proposed = f"{lines[-1]} {word}" if lines else word
        if lines and pen.textbbox((0, 0), proposed, font=font)[2] > width:
            lines.append(word)
        elif lines:
            lines[-1] = proposed
        else:
            lines.append(word)
    return "\n".join(lines)


def tier(depth, inner, outer, center_angle, entries, selected=None):
    count = len(entries)
    sweep = 2*pi if depth == 0 else min(5.5, max(pi/2, count*.42))
    angles = [(pi/2-i*sweep/count if depth == 0 else
               center_angle+sweep/2-(i+.5)*sweep/count) for i in range(count)]
    mask = min(depth, 2)
    for i, (name, icon, color) in enumerate(entries):
        for kind, tint, alpha in (("Pattern", color, .95 if i==selected else .62),
                                   ("Border", None, 1 if i==selected else .86)):
            image = layer_image(f"Wheel{kind}T{mask}N{count:02d}", outer*2,
                                angles[i], tint, alpha)
            canvas.alpha_composite(image, (round(center[0]-outer), round(center[1]-outer)))
    pen = ImageDraw.Draw(canvas)
    band = outer-inner
    icon_size = min(46, band*.46)
    for i, (name, icon, color) in enumerate(entries):
        angle = angles[i]
        mid = (inner+outer)/2
        width = min(132,max(48,mid*sweep/count*.86),band*(.84 if depth==0 else .64 if count>14 else .72))
        height = max(25,band*.47)
        radial_need = min((icon_size+width)/2/max(.01,abs(cos(angle))),
                          (icon_size+height)/2/max(.01,abs(sin(angle))))+3
        tangent_need = min((icon_size+width)/2/max(.01,abs(sin(angle))),
                           (icon_size+height)/2/max(.01,abs(cos(angle))))+3
        tangent = tangent_need<mid*sweep/count*.6 and (
            radial_need>band*.65 or tangent_need/(mid*sweep/count)<radial_need/band)
        distance = tangent_need if tangent else radial_need
        ix = round(center[0]+cos(angle)*mid-(sin(angle)*distance/2 if tangent else -cos(angle)*distance/2))
        iy = round(center[1]-sin(angle)*mid-(cos(angle)*distance/2 if tangent else sin(angle)*distance/2))
        picture = blp(icon).resize((round(icon_size),)*2, Image.Resampling.LANCZOS)
        canvas.alpha_composite(picture, (ix-picture.width//2, iy-picture.height//2))
        lx = round(center[0]+cos(angle)*mid+(sin(angle)*distance/2 if tangent else -cos(angle)*distance/2))
        ly = round(center[1]-sin(angle)*mid+(cos(angle)*distance/2 if tangent else sin(angle)*distance/2))
        # Runtime hides all per-sector labels; names appear only on hub hover.
        jewel = ("Red" if color == red else "Blue" if color == bank else
                 "Purple" if color == purple else "Yellow" if color == gold else
                 "Orange" if color == orange else "Pink" if color == pink else
                 "Cyan" if color == teal else "Green")
        if jewel == "Cyan" and i != selected:
            jewel = "Green"  # Cyan inactive artwork has not arrived yet.
        medallion_size = round(max(14,min(34,outer*sweep/count*.38)))
        mr = outer
        medallion = layer_image(f"Medallion{jewel}{'Active' if i==selected else 'Inactive'}",
                                medallion_size/.70,angle+pi)
        canvas.alpha_composite(medallion,
            (round(center[0]+cos(angle)*mr-medallion.width/2),
             round(center[1]-sin(angle)*mr-medallion.height/2)))
    return angles


bank=(40,112,255); purple=(172,53,216); red=(238,48,48)
green=(8,190,120); orange=(238,137,0); teal=(0,189,213)
gold=(233,175,0); pink=(229,43,130)
root=[("Bank","PackBank",bank),("Auction House","PackAuctionHouse",purple),
      ("Repair","PackRepair",red),("Vendor","PackProfessionVendor",green),
      ("Mailbox","PackMailbox",orange),("Trainer","PackProfessionTrainer",teal),
      ("Travel","PackTravel",gold),("Custom","PackSettings",pink),
      ("Quests","PackQuestmark",gold),("Skills","ServiceSkills",teal),
      ("Items","ServiceItems",orange)]
vendors=[("Food","PackFood",red),("Reagents","PackReagents",purple),
         ("Ammo","PackAmmo",orange),("Profession Vendor","PackProfessionVendor",green),
         ("General Goods","PackGeneral",green),("Back","PackBack",gold)]
professions=[("Alchemy Vendor","PackAlchemyVendor",green),
             ("Mining Vendor","PackMiningVendor",green),
             ("Cooking Vendor","PackCookingVendor",green),
             ("First Aid Vendor","PackFirstAidVendor",green),
             ("Fishing Vendor","PackFishingVendor",green),
             ("Back","PackBack",gold)]
a=tier(0,56,200,pi/2,root,selected=3)
b=tier(1,200,200/.70,a[3],vendors,selected=3)
tier(2,200/.70,200/.70/.74,b[3],professions,selected=0)
hub = blp("WheelCenter").resize((114,114),Image.Resampling.LANCZOS)
canvas.alpha_composite(hub,(center[0]-57,center[1]-57))
hover = blp("WheelCenterHover").resize((160,160),Image.Resampling.LANCZOS)
canvas.alpha_composite(hover,(center[0]-80,center[1]-80))
ImageDraw.Draw(canvas).multiline_text(center,"Blacksmithing\nTrainer",font=font,anchor="mm",
                                  align="center",spacing=4,fill="#fff0d0")

pen = ImageDraw.Draw(canvas)
pen.text((50,30),"ErrandMaster · attached rings",font=header,fill="#ebc17e")
pen.text((955,410),"VENDOR",font=header,fill="#1ae697")
pen.text((955,446),"Sector labels hidden; hub hover shown",font=font,fill="#fff0d0")
pen.text((955,468),"Normal unhovered hub retains its filled art",font=font,fill="#fff0d0")
pen.text((50,924),"Offline approximation · validate rotation, text and hit areas in Forever Beta",font=font,fill="#b9afa3")
OUT.parent.mkdir(exist_ok=True)
canvas.convert("RGB").save(OUT)
print(OUT)
