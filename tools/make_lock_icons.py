"""assets/icons/lock.png and unlock.png: the gate's LOCK / UNLOCK command icons (a padlock, drawn
here in code: the frame is taken from the HOLD icon). python3 tools/make_lock_icons.py"""
from PIL import Image, ImageDraw

frame = Image.open("assets/icons/hold.png").convert("RGBA")
bg = frame.getpixel((9, 9))
DARK = (24, 18, 14, 255)
STEEL = (178, 188, 200, 255)
STEEL_D = (110, 120, 134, 255)
GOLD = (254, 208, 3, 255)
GOLD_L = (255, 232, 110, 255)
GOLD_D = (190, 140, 10, 255)


def icon(locked: bool, name: str) -> None:
    im = frame.copy()
    d = ImageDraw.Draw(im)
    d.rectangle((6, 6, 57, 57), fill=bg)
    # shackle (outline, then steel); the open one swings up and to the side
    if locked:
        d.rounded_rectangle((20, 8, 43, 36), radius=10, fill=DARK)
        d.rounded_rectangle((24, 12, 39, 36), radius=7, fill=bg)
        d.rounded_rectangle((22, 10, 41, 36), radius=9, outline=STEEL, width=3)
        d.rectangle((22, 28, 25, 36), fill=STEEL)
        d.rectangle((38, 28, 41, 36), fill=STEEL)
    else:
        d.rounded_rectangle((26, 5, 49, 33), radius=10, fill=DARK)
        d.rounded_rectangle((30, 9, 45, 33), radius=7, fill=bg)
        d.rounded_rectangle((28, 7, 47, 33), radius=9, outline=STEEL, width=3)
        d.rectangle((28, 26, 31, 33), fill=bg)
        d.rectangle((28, 26, 31, 30), fill=bg)
    # body
    d.rounded_rectangle((13, 29, 50, 56), radius=4, fill=DARK)
    d.rounded_rectangle((15, 31, 48, 54), radius=3, fill=GOLD)
    d.rectangle((15, 31, 48, 36), fill=GOLD_L)
    d.rectangle((15, 49, 48, 54), fill=GOLD_D)
    d.line((15, 31, 48, 31), fill=(255, 245, 170, 255))
    # keyhole
    d.ellipse((28, 38, 35, 45), fill=DARK)
    d.polygon([(30, 44), (33, 44), (34, 51), (29, 51)], fill=DARK)
    im.save("assets/icons/%s.png" % name)


icon(True, "lock")
icon(False, "unlock")
