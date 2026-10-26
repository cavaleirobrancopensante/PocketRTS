"""Clock Soldier WALK built in code from the painted idle sheet (ChatGPT art moved, nothing redrawn). Each leg stays
attached at the hip: the foot is sheared forward/back and the leg is shortened when the foot lifts, lengthened when it
reaches toward the camera. Out: art/redraws/clock_soldier_walk.png (5 rows x 6 frames) and a preview GIF."""
import math, numpy as np
from PIL import Image
exec(open('tools/soldier_guide/walk_guide.py').read().split("W,H=1536,1024")[0])
A=11.0; L=7.0
def warp_leg(F,lm,hip,s,lift,fx,fy):
    h,w=lm.shape; out=np.zeros_like(F); om=np.zeros_like(lm)
    ys,xs=np.nonzero(lm)
    if len(ys)==0: return out,om
    bot=ys.max(); Lh=max(1,bot-hip)
    newL=max(4,Lh+fy*s-lift)
    for y in range(hip,h):
        for x in range(w):
            pass
    # inverse map: for each target pixel find the source pixel
    yy,xx=np.mgrid[0:h,0:w]
    ty=yy-hip; frac=np.clip(ty/newL,0,None)
    sy=(hip+frac*Lh).round().astype(int)
    sx=(xx-fx*s*np.clip(frac,0,1)).round().astype(int)
    ok=(ty>=0)&(sy<h)&(sx>=0)&(sx<w)
    sel=np.zeros_like(lm); sel[ok]=lm[sy[ok],sx[ok]]
    out[sel]=F[sy[sel],sx[sel]]; om=sel
    return out,om
def frames_for(r):
    box,hip,split,far,(fx,fy)=ROWS[r]
    x0,y0,x1,y1=box; F=im[y0:y1,x0:x1]; M=np.abs(F-NAVY).sum(2)>45
    X=excl_mask(M.shape,EXCL[r]); body=M.copy(); body[hip:,:]&=X[hip:,:]; M2=M&~X
    legL=np.zeros_like(M); legL[hip:,:split]=M2[hip:,:split]
    legR=np.zeros_like(M); legR[hip:,split:]=M2[hip:,split:]
    # pad so the legs can stretch
    P=16
    Fp=np.zeros((F.shape[0]+P,F.shape[1]+2*P,3),int); Fp[:]=NAVY; Fp[:F.shape[0],P:P+F.shape[1]]=F
    def pad(m): o=np.zeros(Fp.shape[:2],bool); o[:m.shape[0],P:P+m.shape[1]]=m; return o
    body,legL,legR=pad(body),pad(legL),pad(legR)
    res=[]
    for c in range(6):
        p=c/6.0
        sA=math.cos(2*math.pi*p)*A; lA=max(0.0,math.sin(2*math.pi*p))*L
        sB=-sA; lB=max(0.0,-math.sin(2*math.pi*p))*L
        bob=round(1.5*abs(math.cos(2*math.pi*p)))
        cell=np.zeros_like(Fp); cell[:]=NAVY
        legs=[('L',legL,sA,lA),('R',legR,sB,lB)]
        if far: legs.sort(key=lambda t:0 if t[0]==far else 1)
        for name,lm,s,lift in legs:
            src=Fp.copy()
            if far and name==far: src=(src*0.85).astype(int)
            o,om=warp_leg(src,lm,hip,s,lift,fx,fy)
            cell[om]=o[om]
        b=np.roll(body,bob,axis=0); bs=np.roll(Fp,bob,axis=0)
        cell[b]=bs[b]
        res.append(cell)
    return res
W,H=1536,1024; CW,CH=W//6,H//5
sheet=np.zeros((H,W,3),int); sheet[:]=NAVY
gif=[[] for _ in range(6)]
for r in range(5):
    fr=frames_for(r)
    for c,cell in enumerate(fr):
        cx=c*CW+(CW-cell.shape[1])//2; cy=r*CH+(CH-cell.shape[0])//2
        sheet[cy:cy+cell.shape[0],cx:cx+cell.shape[1]]=cell
Image.fromarray(sheet.astype('uint8')).save('art/redraws/clock_soldier_walk.png')
# preview gif: the 5 directions side by side, walking
rows=[[Image.fromarray(sheet[r*CH:(r+1)*CH, c*CW:(c+1)*CW].astype('uint8')) for c in range(6)] for r in range(5)]
g=[]
for c in range(6):
    o=Image.new('RGB',(5*CW,CH)); [o.paste(rows[r][c],(r*CW,0)) for r in range(5)]; g.append(o)
g[0].save('art/redraws/clock_soldier_walk.gif',save_all=True,append_images=g[1:],duration=140,loop=0)
print('ok')
