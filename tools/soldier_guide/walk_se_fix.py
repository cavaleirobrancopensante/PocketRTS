"""Rebuild the SE row of the mixed walk: clean leg masks (boxes), sword kept with the body, legs sheared at the hip."""
import numpy as np, math
from PIL import Image
exec(open('tools/soldier_guide/walk_guide.py').read().split("W,H=1536,1024")[0])
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

r=1
box,hip,split,far,(fx,fy)=ROWS[r]; hip=104
x0,y0,x1,y1=box; F=im[y0:y1,x0:x1]; M=np.abs(F-NAVY).sum(2)>45
SW=excl_mask(M.shape,(None,None,(22,98,72,168,7)))&M
legL=np.zeros_like(M); legL[104:,20:64]=M[104:,20:64]&~SW[104:,20:64]
legR=np.zeros_like(M); legR[104:,66:110]=M[104:,66:110]&~SW[104:,66:110]
body=M&~legL&~legR
P=16
def pad(a,v):
    o=np.zeros((a.shape[0]+P,a.shape[1]+2*P)+a.shape[2:],a.dtype)
    if v is not None: o[:]=v
    o[:a.shape[0],P:P+a.shape[1]]=a; return o
Fp=pad(F,NAVY); bodyp,lLp,lRp=pad(body,None),pad(legL,None),pad(legR,None)
A=9.0; L=7.0
fr=[]
for c in range(6):
    p=c/6.0
    sA=math.cos(2*math.pi*p)*A; lA=max(0.0,math.sin(2*math.pi*p))*L
    sB=-sA; lB=max(0.0,-math.sin(2*math.pi*p))*L
    bob=round(1.5*abs(math.cos(2*math.pi*p)))
    cell=np.zeros_like(Fp); cell[:]=NAVY
    for name,lm,s,lift in (('R',lRp,sB,lB),('L',lLp,sA,lA)):
        src=Fp.copy()
        if name=='R': src=(src*0.85).astype(int)
        o,om=warp_leg(src,lm,hip,s,lift,fx,fy); cell[om]=o[om]
    b=np.roll(bodyp,bob,axis=0); bs=np.roll(Fp,bob,axis=0); cell[b]=bs[b]
    fr.append(cell)
sheet=np.array(Image.open('art/redraws/clock_soldier_walk_mix.png').convert('RGB')).astype(int)
CW,CH=256,204
for c,cell in enumerate(fr):
    sheet[CH:2*CH, c*CW:(c+1)*CW]=NAVY
    cx=c*CW+(CW-cell.shape[1])//2; cy=CH+(CH-cell.shape[0])//2
    sheet[cy:cy+cell.shape[0],cx:cx+cell.shape[1]]=cell
S=Image.fromarray(sheet.astype('uint8')); S.save('art/redraws/clock_soldier_walk_mix.png')
o=Image.new('RGB',(6*180,170))
for c in range(6): o.paste(S.crop((c*CW+40,CH+20,c*CW+220,CH+190)),(c*180,0))
o.resize((2160,340),Image.NEAREST).save('/tmp/claude-0/-home-claude/3bf5c283-94b1-59fe-b83b-7f9d81ecfc35/scratchpad/se_row.png')
g=[]
for c in range(6):
    f=Image.new('RGB',(5*CW,CH))
    for rr in range(5): f.paste(S.crop((c*CW,rr*CH,(c+1)*CW,(rr+1)*CH)),(rr*CW,0))
    g.append(f)
g[0].save('art/redraws/clock_soldier_walk_mix.gif',save_all=True,append_images=g[1:],duration=140,loop=0)
