"""Regulator working animation: the painted pendulum (from the BUILT cell of art/redraws/regulator.png) swung in code
inside its glass window; the rest of the building is the untouched painted frame."""
import math, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
im=np.array(Image.open('art/redraws/regulator.png').convert('RGB')).astype(int)
CELL=(40,100,360,470); x0,y0,x1,y1=CELL
B=im[y0:y1,x0:x1].copy()
PIV=(221-x0,302-y0)
WIN=(197-x0,303-y0,247-x0,382-y0)            # glass window interior
wx0,wy0,wx1,wy1=WIN
reg=B[wy0:wy1,wx0:wx1]
lum=reg.sum(2); r,g,b=reg[...,0],reg[...,1],reg[...,2]
gold=(r>g)&(r>b+40)&(lum>210)
gold=ndi.binary_dilation(gold,iterations=1)
lab,n=ndi.label(gold); keep=np.zeros_like(gold)
for k in range(1,n+1):
    ys,xs=np.nonzero(lab==k)
    if xs.min()>3 and xs.max()<reg.shape[1]-4: keep|=lab==k   # not the window frame
PM=np.zeros(B.shape[:2],bool); PM[wy0:wy1,wx0:wx1]=keep
# glass behind: fill by vertical then horizontal interpolation of the glass rows
glass=B.copy()
for y in range(wy0,wy1):
    row=PM[y,wx0:wx1]
    if not row.any(): continue
    good=np.nonzero(~row)[0]
    for x in np.nonzero(row)[0]:
        l=good[good<x]; rr=good[good>x]
        if len(l) and len(rr):
            t=(x-l[-1])/(rr[0]-l[-1]); glass[y,wx0+x]=(1-t)*B[y,wx0+l[-1]]+t*B[y,wx0+rr[0]]
        elif len(l): glass[y,wx0+x]=B[y,wx0+l[-1]]
        elif len(rr): glass[y,wx0+x]=B[y,wx0+rr[0]]
rgba=np.zeros(B.shape[:2]+(4,),np.uint8); rgba[...,:3]=B; rgba[...,3]=PM*255
PEND=Image.fromarray(rgba,'RGBA')
ANG=[0,-11,-15,-11,0,11,15,11]
frames=[]
for a in ANG:
    f=Image.fromarray(glass.astype(np.uint8))
    p=PEND.rotate(a,resample=Image.NEAREST,center=PIV)
    m=Image.new('L',f.size,0); ImageDraw.Draw(m).rectangle((wx0+1,wy0,wx1-2,wy1-1),fill=255)
    pa=np.array(p); al=np.minimum(pa[...,3],np.array(m)).astype(np.uint8); p.putalpha(Image.fromarray(al))
    f.paste(p,(0,0),p); frames.append(f)
frames[0].save('art/redraws/regulator_work.gif',save_all=True,append_images=frames[1:],duration=140,loop=0)
s=Image.new('RGB',(4*320,2*370)); [s.paste(f,((i%4)*320,(i//4)*370)) for i,f in enumerate(frames)]
s.save('art/redraws/regulator_work.png')
