from PIL import Image
import numpy as np, math
exec(open('mw_key.py').read().split("frames=[]")[0])   # gives cell, base (key erased), bow, bm, AX, BX0, BY0
B=np.array(base).astype(int)
lum=B.sum(2)
# body sprite: the second hanging body, below the rail
bx0,by0,bx1,by1=117,298,153,374
from scipy import ndimage as _n
body=B[by0:by1,bx0:bx1].copy(); bmask=_n.binary_dilation(body.sum(2)>150,iterations=1)
_yy=np.arange(by1-by0)[:,None]; bmask&=np.ones_like(bmask)
bc=((bx0+bx1)/2,by0)                 # hang point of that body
STEP=np.array([33.0,15.0])
# erase all four bodies: dilated masks, filled by interpolating each row across the hole
from scipy import ndimage as ndi
clean=B.copy()
EM=np.zeros(B.shape[:2],bool); BM=[]
BODIES=[(84,283,121,362),(117,298,153,374),(150,314,184,390)]
for (x0,y0,x1,y1) in [(84,283,121,362),(117,298,153,374),(150,314,184,390)]:
    m=np.zeros(B.shape[:2],bool); m[y0:y1,x0:x1]=B[y0:y1,x0:x1].sum(2)>150
    m=ndi.binary_dilation(m,iterations=2)
    # keep the rail: only below the rail line through the hang points
    yy,xx=np.mgrid[0:B.shape[0],0:B.shape[1]]
    m&=yy>(298+(xx-135)*15/33.0+3)
    EM|=m; BM.append(m)
for y in np.nonzero(EM.any(1))[0]:
    row=EM[y]; xs=np.nonzero(row)[0]
    good=np.nonzero(~row)[0]
    for x in xs:
        l=good[good<x]; r=good[good>x]
        if len(l) and len(r):
            xl,xr=l[-1],r[0]; t=(x-xl)/(xr-xl); clean[y,x]=(1-t)*B[y,xl]+t*B[y,xr]
# foreground parts that stand in front of the line (pasted back on top)
def fg(box,th=150):
    x0,y0,x1,y1=box; m=np.zeros(B.shape[:2],bool); sub=B[y0:y1,x0:x1].sum(2)>th; m[y0:y1,x0:x1]=sub; return m
FG=fg((38,240,82,430),90)|fg((182,318,226,425),90)|fg((250,330,282,430),90)|fg((60,382,270,440),90)
PRESS=(182,318,226,372)
def frame(i):
    t=i/8.0
    f=clean.copy()
    # press stamp: down on frames 2-4
    d=[0,2,4,5,3,1,0,0][i]
    # bodies swing in place on their hooks, each a little out of step (no sliding: nothing passes behind the press)
    for j,(x0,y0,x1,y1) in enumerate(BODIES):
        reg=B[y0:y1,x0:x1]; m=BM[j][y0:y1,x0:x1]
        rgba=np.zeros(reg.shape[:2]+(4,),np.uint8); rgba[...,:3]=reg; rgba[...,3]=m*255
        im=Image.fromarray(rgba,'RGBA')
        ang=5.0*math.sin(2*math.pi*(i/8.0)+j*1.3)
        hx=(x1-x0)/2.0; hy=0
        im=im.rotate(ang,resample=Image.NEAREST,center=(hx,hy),expand=False)
        ra=np.array(im); mm=ra[...,3]>128
        sub=f[y0:y1,x0:x1]; sub[mm]=ra[...,:3][mm]
    # parts in front go back on top (posts, beam, press frame) except the moving press head
    keep=FG.copy(); x0,y0,x1,y1=PRESS; keep[y0:y1,x0:x1]=False
    f[keep]=B[keep]
    # the press head on top, shifted by d
    blk=B[y0:y1,x0:x1]; pm=blk.sum(2)>90
    sub=f[y0+d:y1+d,x0:x1]; sub[pm]=blk[pm]
    img=Image.fromarray(f.astype('uint8'))
    # the key
    th=math.pi*i/8; c=math.cos(th); w=max(0.13,abs(c)); bw=max(3,int(bow.width*w))
    bi=bow.resize((bw,bow.height),Image.LANCZOS); mi=bm.resize((bw,bow.height),Image.LANCZOS)
    if c<0: bi=bi.transpose(Image.FLIP_LEFT_RIGHT); mi=mi.transpose(Image.FLIP_LEFT_RIGHT)
    from PIL import ImageEnhance
    bi=ImageEnhance.Brightness(bi).enhance(0.78+0.22*abs(c))
    img.paste(bi,(int(AX-bw/2),BY0),mi)
    return img
fr=[frame(i) for i in range(8)]
fr[0].save('mw_all2.gif',save_all=True,append_images=fr[1:],duration=140,loop=0)
big=[f.crop((20,60,384,480)).resize((728,840),Image.NEAREST) for f in fr[:4]]
s=Image.new('RGB',(728*4,840)); [s.paste(b,(i*728,0)) for i,b in enumerate(big)]
s.resize((1456,420)).save('mw_all2_strip.png')
