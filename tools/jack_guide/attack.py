"""Jack ATTACK from the painted idle frame and ChatGPT's screw fx sheet: the unit recoils along its barrel, the muzzle
burst (art/redraws/jack_screw_fx.png row 2) plays at the drill tip, rotated to the barrel; the screw itself flies as a
projectile in the game. Out: art/redraws/jack_attack.png (5 rows x 6 frames) and .gif."""
import math, numpy as np
from PIL import Image
NAVY=np.array([0,22,48])
im=Image.open('art/redraws/jack_idle.png').convert('RGB')
fx=Image.open('art/redraws/jack_screw_fx.png').convert('RGB')
BOX=[(159,23,306,181),(174,216,299,360),(170,387,301,537),(166,571,308,713),(164,743,308,873)]
TIP=[(5,115),(4,116),(131,92),(140,92),(141,90)]          # drill tip in crop coords
DIRDEG=[125,120,0,18,60]                                 # barrel direction, screen degrees (0 = right, + = down... PIL ccw)
BURST=[(60,360,330,600),(420,360,720,600),(800,360,1120,600),(1210,400,1460,560)]
def rgba(img):
    a=np.array(img).astype(int); m=np.abs(a-NAVY).sum(2)>40
    o=np.zeros(a.shape[:2]+(4,),np.uint8); o[...,:3]=a; o[...,3]=m*255; return Image.fromarray(o,'RGBA')
BUR=[rgba(fx.crop(b)) for b in BURST]
REC=[0,3,2,1,0,0]; BF=[None,0,1,2,3,None]
CW,CH=256,204
sheet=Image.new('RGB',(1536,1024),tuple(NAVY))
for r,b in enumerate(BOX):
    spr=rgba(im.crop(b)); w,h=spr.size
    th=math.radians(DIRDEG[r]); dx,dy=math.cos(th),math.sin(th)
    for c in range(6):
        cell=Image.new('RGBA',(CW,CH),(0,0,0,0))
        ox=(CW-w)//2-int(round(dx*REC[c])); oy=CH-h-10-int(round(dy*REC[c]*0.5))
        cell.alpha_composite(spr,(ox,oy))
        if BF[c] is not None:
            bimg=BUR[BF[c]]; k=0.32; bimg=bimg.resize((int(bimg.width*k),int(bimg.height*k)),Image.LANCZOS)
            bimg=bimg.rotate(-DIRDEG[r],resample=Image.BICUBIC,expand=True)
            tx=ox+TIP[r][0]+dx*bimg.width*0.42; ty=oy+TIP[r][1]+dy*bimg.height*0.42
            cell.alpha_composite(bimg,(int(tx-bimg.width/2),int(ty-bimg.height/2)))
        bg=Image.new('RGB',(CW,CH),tuple(NAVY)); bg.paste(cell,(0,0),cell); sheet.paste(bg,(c*CW,r*CH))
sheet.save('art/redraws/jack_attack.png')
g=[]
for c in range(6):
    o=Image.new('RGB',(5*CW,CH))
    for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
    g.append(o)
g[0].save('art/redraws/jack_attack.gif',save_all=True,append_images=g[1:],duration=[220,70,80,90,110,220],loop=0)
print('ok')
