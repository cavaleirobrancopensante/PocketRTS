from PIL import Image
import numpy as np, math
R='/home/claude/pocketrts/art/redraws/'
NAVY=(0,22,48)
def navy(a): return (a[...,2]>a[...,0]+25)&(a[...,2]>a[...,1]+10)
def prep(img):
    a=np.array(img.convert('RGB')).astype(int); m=~navy(a)
    ys,xs=np.nonzero(m); cx=(xs.min()+xs.max())/2; cy=(ys.min()+ys.max())/2; Rr=(xs.max()-xs.min())/2
    return a,m,cx,cy,Rr
def phase(m,cx,cy,Rr,N,frac=0.97):
    n=3600; s=c=0
    for i in range(n):
        t=2*math.pi*i/n; x=int(round(cx+frac*Rr*math.cos(t))); y=int(round(cy+frac*Rr*math.sin(t)))
        if m[y,x]: s+=math.sin(N*t); c+=math.cos(N*t)
    return math.atan2(s,c)/N   # angle of a tooth centre (image coords, y down)
def load(path,box,N):
    im=Image.open(path).convert('RGB').crop(box)
    a,m,cx,cy,Rr=prep(im)
    ph=phase(m,cx,cy,Rr,N)
    sq=int(Rr*2+8); 
    c=Image.new('RGB',(2*int(max(cx,im.width-cx,cy,im.height-cy))+4,)*2,NAVY)
    ox=c.width//2-int(cx); oy=c.height//2-int(cy)
    c.paste(im,(ox,oy))
    return dict(img=c,R=Rr,N=N,ph=ph)
tower=load(R+'cog_ring_clocktower_flat.png',(0,0,1254,1254),30)
small=load(R+'cog_rings_building_flat.png',(0,0,600,1024),22)
print(tower['ph'],small['ph'])
P=70.0; K=0.5          # target tooth pitch (arc, working px at full size), global scale
def scale_of(g): return (P/ (2*math.pi*0.965*g['R']/g['N']))*K
def scaled(g):
    s=scale_of(g); im=g['img'].resize((int(g['img'].width*s),int(g['img'].height*s)),Image.LANCZOS)
    return im, g['R']*s
ti,tR=scaled(tower); si,sR=scaled(small)
print('radii',tR,sR)
Dc=0.965*(tR+sR)
SQ=0.64; DEP=9
angles=[math.radians(-30),math.radians(150)]   # directions from tower to presses (image coords, y down)
def meshing_offsets():
    offs=[]
    for phi in angles:
        thA=0.0
        u=((phi-tower['ph']-thA)*tower['N']/(2*math.pi))%1
        thB0=phi+math.pi-small['ph']-(0.5-u)*2*math.pi/small['N']
        offs.append(thB0)
    return offs
offs=meshing_offsets()
W=int(2*(Dc+sR)+40); H=int(2*(Dc+sR)+40)
cx0,cy0=W//2,H//2
def paste_ring(canvas,im,cx,cy,theta):
    r=im.rotate(-math.degrees(theta),resample=Image.BICUBIC,fillcolor=NAVY)
    a=np.array(r).astype(int); m=Image.fromarray((~navy(a)*255).astype('uint8'))
    canvas.paste(r,(int(cx-r.width/2),int(cy-r.height/2)),m)

def ringmask(im,theta):
    r=im.rotate(-math.degrees(theta),resample=Image.BICUBIC,fillcolor=NAVY)
    return ~navy(np.array(r).astype(int))
def best_dist(phi,o):
    A=ringmask(ti,0.0); B=ringmask(si,o)
    best=None
    for d in np.arange(Dc+14,Dc-30,-0.5):
        bx=cx0+d*math.cos(phi); by=cy0+d*math.sin(phi)
        canvas=np.zeros((H,W),bool); ca=np.zeros((H,W),bool)
        ay=A.shape[0]; 
        x0=int(cx0-A.shape[1]/2); y0=int(cy0-A.shape[0]/2); ca[y0:y0+A.shape[0],x0:x0+A.shape[1]]=A
        x1=int(bx-B.shape[1]/2); y1=int(by-B.shape[0]/2)
        cb=np.zeros((H,W),bool)
        ys0=max(y1,0); xs0=max(x1,0)
        sub=B[ys0-y1:ys0-y1+min(H-ys0,B.shape[0]-(ys0-y1)), xs0-x1:xs0-x1+min(W-xs0,B.shape[1]-(xs0-x1))]
        cb[ys0:ys0+sub.shape[0],xs0:xs0+sub.shape[1]]=sub
        ov=(ca&cb).sum()
        if ov>60: break
        best=d
    return best
DISTS=[]
newoffs=[]
for p,o in zip(angles,offs):
    best=(1e9,None)
    step=2*math.pi/small['N']/24
    for k in range(-14,15):
        oo=o+k*step
        d=best_dist(p,oo)
        if d is not None and d<best[0]: best=(d,oo)
    DISTS.append(best[0]); newoffs.append(best[1])
offs=newoffs
print('dists',DISTS,'Dc',Dc)
import pickle
CORR=pickle.load(open('corr.pkl','rb'))
def frame(i):
    th=math.radians(1.0*i)
    c=Image.new('RGB',(W,H),NAVY)
    paste_ring(c,ti,cx0,cy0,th)
    for phi,o in zip(angles,offs):
        thB=o-th*tower['N']/small['N']+CORR[angles.index(phi)][i]
        paste_ring(c,si,cx0+DISTS[angles.index(phi)]*math.cos(phi),cy0+DISTS[angles.index(phi)]*math.sin(phi),thB)
    # squash and extrude
    h2=int(H*SQ); c=c.resize((W,h2),Image.LANCZOS)
    a=np.array(c).astype(int); m=~navy(a)
    out=np.zeros((h2+DEP,W,3),int); out[:]=NAVY
    for d in range(DEP,0,-1):
        sh=np.zeros_like(m); sh[d:]=m[:-d]
        t=1-d/DEP; col=(np.array([72,46,18])*(0.55+0.45*t)).astype(int)
        sel=sh[:h2]&~m
        o=out[:h2]; o[sel]=col
    # bottom strip beyond h2
    for d in range(1,DEP+1):
        pass
    out[:h2][m]=a[m]
    return Image.fromarray(out.astype('uint8'))
fr=[frame(i) for i in range(48)]
bb=np.array(fr[0]).astype(int); mm=~navy(bb); ys,xs=np.nonzero(mm)
box=(max(xs.min()-10,0),max(ys.min()-10,0),xs.max()+10,ys.max()+10)
fr=[f.crop(box) for f in fr]
fr[0].save('gears_demo.gif',save_all=True,append_images=fr[1:],duration=60,loop=0)
fr[0].save('gears_demo_f0.png'); print(fr[0].size)
