"""Zooboxi app icon, built from the real logo.

The owner's call (2026-09-07): the icon is the WHOLE logo — the dog, the cat,
the smiling box and the Zooboxi wordmark — not a cropped mark. It is drawn on
the brand's own paper (a soft cream) because that is the ground the artwork was
designed for; on the brand teal the wordmark's own outline fights the field.

This script writes the two SOURCES pubspec points at — assets/brand/app_icon_1024.png
(the full-bleed master) and assets/brand/app_mark.png (the same logo on
transparency, for Android's adaptive foreground). The platform sizes belong to
one generator, and that generator is flutter_launcher_icons:

    python3 tools/build_icons.py && dart run flutter_launcher_icons

The Android copy is drawn smaller: the launcher insets the foreground and then
masks it to a circle, and a wide logo whose corners fall outside that circle
comes back with its sparkles bitten off.
"""
import os
from PIL import Image, ImageDraw

APP=os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/'
B=APP+'assets/brand/'
S=1024

# The brand's paper, with just enough warmth in it not to read as a blank tile.
TOP=(255,255,255); BOTTOM=(251,238,219)

logo=Image.open(B+'logo_full.png').convert('RGBA')
logo=logo.crop(logo.split()[3].getbbox())

def vgrad(size,t,b):
    g=Image.new('RGB',(1,size[1])); d=ImageDraw.Draw(g)
    for y in range(size[1]):
        k=y/max(1,size[1]-1)
        d.point((0,y),tuple(int(t[i]+(b[i]-t[i])*k) for i in range(3)))
    return g.resize(size,Image.BICUBIC)

def fitted(canvas_size, fill):
    """The logo, scaled to [fill] of the canvas by its LONGEST side, centred."""
    side=round(canvas_size*fill)
    w,h=logo.size
    if w>=h:
        size=(side, max(1, round(h*side/w)))
    else:
        size=(max(1, round(w*side/h)), side)
    art=logo.resize(size, Image.LANCZOS)
    layer=Image.new('RGBA',(canvas_size,canvas_size),(0,0,0,0))
    layer.paste(art, ((canvas_size-art.width)//2,(canvas_size-art.height)//2), art)
    return layer

master=Image.new('RGB',(S,S)); master.paste(vgrad((S,S),TOP,BOTTOM))
art=fitted(S,0.86)
master.paste(art,(0,0),art)
master.save(B+'app_icon_1024.png')

# Android's adaptive foreground: the logo alone, small enough that the
# launcher's circular mask cannot clip the sparkles off its corners.
fitted(1024,0.50).save(B+'app_mark.png')

print('wrote assets/brand/app_icon_1024.png + app_mark.png')
print('now run: dart run flutter_launcher_icons')
