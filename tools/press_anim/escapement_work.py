"""Escapement working animation from the painted BUILT cell (art/redraws/escapement.png): the escape wheel steps forward
one notch per tick and the iron anchor rocks left/right on its pivot, in code. Out: art/redraws/escapement_work.png/.gif."""
import math, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
im=np.array(Image.open('art/redraws/escapement.png').convert('RGB')).astype(int)
X0,Y0,X1,Y1=30,90,360,460
B=im[Y0:Y1,X0:X1].copy()
WC=(247-X0,299-Y0); WR=57                   # escape wheel centre and radius
PV=(240-X0,193-Y0)                          # anchor pivot
# the wheel disc (all pixels inside the circle, rotated as a whole)
yy,xx=np.mgrid[0:B.shape[0],0:B.shape[1]]
disc=np.hypot(xx-WC[0],yy-WC[1])<=WR
# the anchor: grey/steel, red tips and brass hub in the band around the pivot, above the wheel's hub
r,g,b=B[...,0],B[...,1],B[...,2]
grey=(np.abs(r-g)<22)&(np.abs(g-b)<26)&(r>70)
red=(r>150)&(g<70)&(b<70)
brass=(r>150)&(g>90)&(b<90)
box=np.zeros_like(disc); box[175-Y0:250-Y0,160-X0:310-X0]=True
shaft=np.zeros_like(disc); shaft[180-Y0:300-Y0,228-X0:252-X0]=True
anchor=box&(grey|red|brass)|shaft&(grey|brass)
anchor=ndi.binary_closing(anchor,iterations=1)&(box|shaft)
DARK=np.array([24,26,38])
base=B.copy()
base[disc]=DARK
base[anchor]=DARK
def rgba(mask):
    o=np.zeros(B.shape[:2]+(4,),np.uint8); o[...,:3]=B; o[...,3]=mask*255; return Image.fromarray(o,'RGBA')
WHEEL=rgba(disc); ANCH=rgba(anchor)
TICK=[0,0,1,1,2,2,3,3]       # wheel steps (one notch each = 360/8/2 degrees)
ROCK=[-5,-2,2,5,5,2,-2,-5]
frames=[]
for i in range(8):
    f=Image.fromarray(base.astype(np.uint8)).convert('RGBA')
    w=WHEEL.rotate(-TICK[i]*22.5,resample=Image.NEAREST,center=WC); f.alpha_composite(w)
    a=ANCH.rotate(ROCK[i],resample=Image.NEAREST,center=PV); f.alpha_composite(a)
    frames.append(f.convert('RGB'))
frames[0].save('art/redraws/escapement_work.gif',save_all=True,append_images=frames[1:],duration=140,loop=0)
s=Image.new('RGB',(4*B.shape[1],2*B.shape[0])); [s.paste(f,((i%4)*B.shape[1],(i//4)*B.shape[0])) for i,f in enumerate(frames)]
s.save('art/redraws/escapement_work.png')
