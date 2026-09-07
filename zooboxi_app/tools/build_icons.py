"""Zooboxi app icon, built from the real logo.

The wordmark is unreadable at 60px, so the icon is the logo's MARK: the two
pets in the smiling box, on the brand teal.

This script writes the two SOURCES pubspec points at — assets/brand/app_icon_1024.png
(the full-bleed master) and assets/brand/app_mark.png (the mark on transparency,
for Android's adaptive foreground). The platform sizes themselves belong to one
generator, and that generator is flutter_launcher_icons:

    python3 tools/build_icons.py && dart run flutter_launcher_icons

The mark is drawn smaller on the transparent version: Android insets the
foreground and then masks it to a circle, and a box whose corners fall outside
that circle comes back with its corners bitten off.
"""
import json, os
from PIL import Image, ImageDraw

APP=os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/'
B=APP+'assets/brand/'
S=1024
TEAL=(66,157,156); TEAL_D=(45,116,116)

logo=Image.open(B+'logo_full.png').convert('RGBA')
box=logo.crop((300,846,1120,1204)); box=box.crop(box.split()[3].getbbox())
pets=Image.open(B+'mascots_peek.png').convert('RGBA'); pets=pets.crop(pets.split()[3].getbbox())
pw,ph=pets.size
pets=pets.crop((int(pw*0.20),0,int(pw*0.80),ph)); pets=pets.crop(pets.split()[3].getbbox())

def vgrad(size,t,b):
    g=Image.new('RGB',(1,size[1])); d=ImageDraw.Draw(g)
    for y in range(size[1]):
        k=y/max(1,size[1]-1)
        d.point((0,y),tuple(int(t[i]+(b[i]-t[i])*k) for i in range(3)))
    return g.resize(size,Image.BICUBIC)

def fit(i,w): return i.resize((w,round(i.height*w/i.width)),Image.LANCZOS)

def mark_layer(canvas_size, fill, ratio=1.10, overlap=0.17, yshift=0):
    """The mark on transparency, centred in a canvas_size square."""
    c=Image.new('RGBA',(canvas_size,canvas_size),(0,0,0,0))
    bw=round(canvas_size*fill); b=fit(box,bw); p=fit(pets,round(bw*ratio))
    ov=round(p.height*overlap); total=p.height+b.height-ov
    top=(canvas_size-total)//2+yshift
    c.paste(p,((canvas_size-p.width)//2,top),p)
    c.paste(b,((canvas_size-b.width)//2,top+p.height-ov),b)
    return c

master=Image.new('RGB',(S,S)); master.paste(vgrad((S,S),TEAL,TEAL_D))
mark=mark_layer(S,0.72)
master.paste(mark,(0,0),mark)
master.save(B+'app_icon_1024.png')

# Android's adaptive foreground: the mark alone, drawn small enough that the
# launcher's circular mask cannot clip the box.
mark_layer(1024, 0.60).save(B+'app_mark.png')

print('wrote assets/brand/app_icon_1024.png + app_mark.png')
print('now run: dart run flutter_launcher_icons')
