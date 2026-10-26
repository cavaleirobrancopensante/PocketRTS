"""Clock Soldier WALK pose guide: the ChatGPT idle sheet's frame 1 per direction, the legs cut at the hip and moved into
a clear 6-frame stride in code (swing leg forward and lifted, stance leg back, body bob). For a ChatGPT repaint."""
import math, numpy as np
from PIL import Image, ImageEnhance
SRC='art/redraws/clock_soldier_idle.png'
OUT='art/redraws/clock_soldier_walk_guide.png'
NAVY=np.array([0,22,48])
im=np.array(Image.open(SRC).convert('RGB')).astype(int)
# per row: crop box, hip y (crop-local), leg split x (crop-local), far leg ('L' or 'R'), forward vector (x, y) on screen
ROWS=[((163,28,338,192),110,88,None,(0.0,0.45)),
      ((186,222,326,388),112,95,'R',(0.7,0.35)),
      ((197,409,317,566),112,58,'L',(1.0,0.0)),
      ((184,599,339,756),112,72,'L',(0.7,-0.35)),
      ((177,791,337,954),112,82,None,(0.0,-0.45))]
A=15.0; L=10.0
# what is NOT leg below the hip (sword and shield stay with the body): x limits and a sword line (x0,y0,x1,y1,width)
EXCL=[(38,120,None),(None,140,(22,98,72,168,9)),(28,None,(52,106,118,152,8)),(35,110,None),(35,118,None)]
def excl_mask(shape,ex):
    lo,hi,line=ex; h,w=shape; yy,xx=np.mgrid[0:h,0:w]; m=np.zeros(shape,bool)
    if lo is not None: m|=xx<lo
    if hi is not None: m|=xx>hi
    if line:
        x0,y0,x1,y1,wd=line; dx,dy=x1-x0,y1-y0; L2=dx*dx+dy*dy
        t=np.clip(((xx-x0)*dx+(yy-y0)*dy)/L2,0,1); d=np.hypot(xx-(x0+t*dx),yy-(y0+t*dy)); m|=d<wd
    return m
W,H=1536,1024; CW,CH=W//6,H//5
sheet=np.zeros((H,W,3),int); sheet[:]=NAVY
def paste(dst,src,msk,x,y):
    h,w=src.shape[:2]; x=int(round(x)); y=int(round(y))
    sub=dst[y:y+h,x:x+w]; mm=msk[:sub.shape[0],:sub.shape[1]]
    sub[mm]=src[:sub.shape[0],:sub.shape[1]][mm]
for r,(box,hip,split,far,(fx,fy)) in enumerate(ROWS):
    x0,y0,x1,y1=box; F=im[y0:y1,x0:x1]; M=np.abs(F-NAVY).sum(2)>45
    h,w=M.shape
    X=excl_mask(M.shape,EXCL[r])
    body=M.copy(); body[hip:,:]&=X[hip:,:]
    M2=M&~X
    legL=np.zeros_like(M); legL[hip:,:split]=M2[hip:,:split]
    legR=np.zeros_like(M); legR[hip:,split:]=M2[hip:,split:]
    for c in range(6):
        p=c/6.0
        sA=math.cos(2*math.pi*p)*A; lA=max(0.0,math.sin(2*math.pi*p))*L
        sB=-sA; lB=max(0.0,math.sin(2*math.pi*p+math.pi))*L
        bob=round(2*abs(math.cos(2*math.pi*p)))
        cell=np.zeros((h+20,w+30,3),int); cell[:]=NAVY
        ox,oy=15,8
        legs=[('L',legL,sA,lA),('R',legR,sB,lB)]
        if far: legs.sort(key=lambda t:0 if t[0]==far else 1)
        for name,lm,s,lift in legs:
            src=F.copy()
            if far and name==far: src=(src*0.82).astype(int)
            paste(cell,src,lm,ox+s*fx,oy+s*fy-lift)
        paste(cell,F,body,ox,oy+bob)
        cx=c*CW+(CW-cell.shape[1])//2; cy=r*CH+(CH-cell.shape[0])//2
        sheet[cy:cy+cell.shape[0],cx:cx+cell.shape[1]]=cell
from scipy import ndimage as ndi
fg=np.abs(sheet-NAVY).sum(2)>45
lab,n=ndi.label(fg); sizes=ndi.sum(fg,lab,range(1,n+1))
for k,sz in enumerate(sizes,1):
    if sz<60: sheet[lab==k]=NAVY
Image.fromarray(sheet.astype('uint8')).save(OUT)
print('saved',OUT)
