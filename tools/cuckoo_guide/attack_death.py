"""Cuckoo ATTACK (air-to-air lunge) and DEATH (spins and falls) built in code from the painted flying sheet
(art/redraws/cuckoo_fly.png: 5 rows S, SE, E, NE, N x 4 wing frames: up, level, down, level). Frames are aligned on the
red body (the ChatGPT cells drift). A code-drawn ground shadow is kept under the bird.
Out: art/redraws/cuckoo_attack.png/.gif (5 x 6) and art/redraws/cuckoo_death.png/.gif (5 x 7)."""
import math, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
a=np.array(Image.open('art/redraws/cuckoo_fly.png').convert('RGB')).astype(int)
H,W=a.shape[:2]; R,C=5,4
def cell_sprite(r,c):
    sub=a[r*H//R:(r+1)*H//R, c*W//C:(c+1)*W//C]
    m=np.abs(sub-NAVY).sum(2)>45
    lab,n=ndi.label(ndi.binary_closing(m,iterations=2)); sz=ndi.sum(m,lab,range(1,n+1)); k=int(np.argmax(sz))+1
    m&=ndi.binary_dilation(lab==k,iterations=2)
    red=m&(sub[...,0]>140)&(sub[...,1]<90)&(sub[...,2]<90)
    ys,xs=np.nonzero(red); cx,cy=xs.mean(),ys.mean()
    o=np.zeros(sub.shape[:2]+(4,),np.uint8); o[...,:3]=sub; o[...,3]=m*255
    ys2,xs2=np.nonzero(m)
    return Image.fromarray(o,'RGBA'), (cx,cy), ys2.max()
SPR=[[cell_sprite(r,c) for c in range(C)] for r in range(R)]
FWD=[(0,1),(0.7,0.5),(1,0),(0.7,-0.5),(0,-1)]
CW,CH=256,204
GROUND=CH-18
def shadow(cell,x,scale=1.0,alpha=150):
    sh=Image.new('RGBA',cell.size,(0,0,0,0)); d=ImageDraw.Draw(sh)
    rx=26*scale; ry=7*scale
    d.ellipse((x-rx,GROUND-ry,x+rx,GROUND+ry),fill=(0,6,18,alpha)); cell.alpha_composite(sh)
def put(cell,r,c,dx,dy,ang=0.0,k=1.0,squash=1.0):
    img,(cx,cy),bot=SPR[r][c]
    if k!=1.0: a2=np.array(img).astype(float); a2[...,:3]*=k; img=Image.fromarray(a2.clip(0,255).astype(np.uint8),'RGBA')
    if squash!=1.0: img=img.resize((img.width,int(img.height*squash)),Image.LANCZOS); cy*=squash
    if ang: img=img.rotate(ang,resample=Image.BICUBIC,center=(cx,cy))
    bx=CW/2+dx; by=GROUND-62+dy
    cell.alpha_composite(img,(int(round(bx-cx)),int(round(by-cy))))
def build(seq,cols,name,durs):
    sheet=Image.new('RGB',(cols*CW,R*CH),tuple(NAVY))
    for r in range(R):
        for c,f in enumerate(seq):
            cell=Image.new('RGBA',(CW,CH),(0,0,0,0)); f(cell,r)
            bg=Image.new('RGB',(CW,CH),tuple(NAVY)); bg.paste(cell,(0,0),cell); sheet.paste(bg,(c*CW,r*CH))
    sheet=sheet.resize((1536,1024),Image.NEAREST) if cols*CW!=1536 else sheet
    sheet.save('art/redraws/%s.png'%name)
    cw=sheet.width//cols; ch=sheet.height//R; g=[]
    for c in range(cols):
        o=Image.new('RGB',(5*cw,ch))
        for r in range(R): o.paste(sheet.crop((c*cw,r*ch,(c+1)*cw,(r+1)*ch)),(r*cw,0))
        g.append(o)
    g[0].save('art/redraws/%s.gif'%name,save_all=True,append_images=g[1:],duration=durs,loop=0)
def lunge(col,d):
    def f(cell,r):
        fx,fy=FWD[r]; shadow(cell,CW/2+fx*d); put(cell,r,col,fx*d,fy*d*0.7)
    return f
ATTACK=[lunge(1,0),lunge(0,-5),lunge(2,16),lunge(3,12),lunge(1,5),lunge(1,0)]
build(ATTACK,6,'cuckoo_attack',[150,110,70,90,110,150])
def fall(col,ang,drop,sx,k=1.0,lying=False):
    def f(cell,r):
        side=1 if r<3 else -1
        img,(cx,cy),bot=SPR[r][col]
        if k!=1.0:
            a2=np.array(img).astype(float); a2[...,:3]*=k; img=Image.fromarray(a2.clip(0,255).astype(np.uint8),'RGBA')
        img=img.crop(img.getbbox())
        if lying:
            img=img.resize((img.width,max(4,int(img.height*0.5))),Image.LANCZOS)   # flat on the ground, seen from above
        elif ang:
            img=img.rotate(ang*side,resample=Image.BICUBIC,expand=True); img=img.crop(img.getbbox())
        x=CW/2+sx*side; y=GROUND-62+drop
        top=y-img.height/2
        if top+img.height>GROUND+4: top=GROUND+4-img.height     # never below the ground
        shadow(cell,x,1.0+0.5*min(1,drop/40.0),150+20*lying)
        cell.alpha_composite(img,(int(round(x-img.width/2)),int(round(top))))
    return f
DEATH=[fall(1,0,-4,0),fall(0,30,8,4),fall(2,110,22,10),fall(1,200,36,16),fall(2,0,60,22,0.9,True),fall(2,0,60,22,0.75,True)]
build(DEATH,6,'cuckoo_death',[120,90,80,80,160,900])
print('ok')
