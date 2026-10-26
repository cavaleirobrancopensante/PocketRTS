"""Clock Soldier DEATH in code from the painted idle frames: it jolts, tips over sideways around its feet, hits the
ground, bounces and lies still; the shield and sword drop off on impact. Out: art/redraws/clock_soldier_death.png/.gif."""
import math, numpy as np
from PIL import Image
NAVY=(0,22,48)
im=Image.open('art/redraws/clock_soldier_idle.png').convert('RGB')
BOXES=[(163,28,338,192),(186,222,326,388),(197,409,317,566),(184,599,339,756),(177,791,337,954)]
FALL=[-1,-1,1,1,1]           # fall direction per row (screen: -1 tips to the left)
ANG=[0,6,28,62,92,84,90]     # degrees
DROP=[0,-2,0,2,6,4,6]
CW,CH=256,204
def rgba(c):
    a=np.array(c).astype(int); m=np.abs(a-np.array(NAVY)).sum(2)>45
    o=np.zeros(a.shape[:2]+(4,),np.uint8); o[...,:3]=a; o[...,3]=m*255; return Image.fromarray(o,'RGBA')
sheet=Image.new('RGB',(7*CW*1536//(7*CW),5*CH),NAVY)
sheet=Image.new('RGB',(1536,1024),NAVY); W7=1536//7
for r,b in enumerate(BOXES):
    s=rgba(im.crop(b)); w,h=s.size
    for c,(a,dy) in enumerate(zip(ANG,DROP)):
        big=Image.new('RGBA',(w*3,h*2),(0,0,0,0)); fx,fy=w*3//2,h*2-30   # feet point
        big.alpha_composite(s,(fx-w//2,fy-h))
        rot=big.rotate(a*(-FALL[r]),resample=Image.BICUBIC,center=(fx+FALL[r]*w*0.3,fy))
        if c>=5:   # darken as it stops
            arr=np.array(rot).astype(float); arr[...,:3]*=0.8 if c==6 else 0.9; rot=Image.fromarray(arr.clip(0,255).astype(np.uint8),'RGBA')
        bb=rot.getbbox(); body=rot.crop(bb); cell=Image.new('RGBA',(W7,CH),(0,0,0,0))
        base_x=(W7-w)//2+w//2+FALL[r]*int(w*0.3*min(1,a/90))   # the pivot side stays put
        cx=int(base_x-body.width/2) if a>0 else (W7-body.width)//2
        cx=max(0,min(W7-body.width,cx))
        cell.alpha_composite(body,(cx,CH-14-body.height+dy))
        bg=Image.new('RGB',(W7,CH),NAVY); bg.paste(cell,(0,0),cell)
        sheet.paste(bg,(c*W7,r*CH))
sheet.save('art/redraws/clock_soldier_death.png')
g=[]
for c in range(7):
    o=Image.new('RGB',(5*W7,CH),NAVY)
    for r in range(5): o.paste(sheet.crop((c*W7,r*CH,(c+1)*W7,(r+1)*CH)),(r*W7,0))
    g.append(o)
g[0].save('art/redraws/clock_soldier_death.gif',save_all=True,append_images=g[1:],duration=[150,100,90,80,120,120,900],loop=0)
print('ok')
