import math, numpy as np, pickle, os
from PIL import Image
src=open('gears_demo3.py').read().split("fr=[frame(i)")[0]
src=src.replace("angles=[math.radians(-30),math.radians(150)]","angles=[math.radians(-40),math.radians(45),math.radians(150)]")
g={}; exec(src,g)
ti,si,tower,small=g['ti'],g['si'],g['tower'],g['small']
angles,offs,DISTS=g['angles'],g['offs'],g['DISTS']
W,H,cx0,cy0=g['W'],g['H'],g['cx0'],g['cy0']; ringmask=g['ringmask']; NAVY=g['NAVY']
NF=48
def fit():
    res=[]
    for phi,o,d in zip(angles,offs,DISTS):
        corr=[]; prev=0.0
        for i in range(NF):
            th=math.radians(1.0*i); nom=o-th*tower['N']/small['N']
            A=ringmask(ti,th); ca=np.zeros((H,W),bool)
            x0=int(cx0-A.shape[1]/2); y0=int(cy0-A.shape[0]/2); ca[y0:y0+A.shape[0],x0:x0+A.shape[1]]=A
            bx=cx0+d*math.cos(phi); by=cy0+d*math.sin(phi); best=(1e9,0)
            for k in range(-24,25):
                c=prev+math.radians(k*0.25); B=ringmask(si,nom+c)
                x1=int(bx-B.shape[1]/2); y1=int(by-B.shape[0]/2); cb=np.zeros((H,W),bool)
                ys0=max(y1,0); xs0=max(x1,0)
                sub=B[ys0-y1:ys0-y1+min(H-ys0,B.shape[0]-(ys0-y1)), xs0-x1:xs0-x1+min(W-xs0,B.shape[1]-(xs0-x1))]
                cb[ys0:ys0+sub.shape[0],xs0:xs0+sub.shape[1]]=sub
                ov=(ca&cb).sum()+abs(k)*1.5
                if ov<best[0]: best=(ov,c)
            prev=best[1]; corr.append(prev)
        res.append(corr)
    return res
if os.path.exists('corr3.pkl'): CORR=pickle.load(open('corr3.pkl','rb'))
else:
    CORR=fit(); pickle.dump(CORR,open('corr3.pkl','wb'))
g['CORR']=CORR
# ring layer frame: same as gears_demo4 frame()
SQ,DEP=g['SQ'],g['DEP']; navy=g['navy']; paste_ring=g['paste_ring']
def rings(i):
    th=math.radians(1.0*i)
    c=Image.new('RGB',(W,H),NAVY); paste_ring(c,ti,cx0,cy0,th)
    for j,(phi,o,d) in enumerate(zip(angles,offs,DISTS)):
        paste_ring(c,si,cx0+d*math.cos(phi),cy0+d*math.sin(phi),o-th*tower['N']/small['N']+CORR[j][i])
    h2=int(H*SQ); c=c.resize((W,h2),Image.LANCZOS)
    a=np.array(c).astype(int); m=~navy(a)
    out=np.zeros((h2+DEP,W,3),int); out[:]=NAVY
    for dd in range(DEP,0,-1):
        sh=np.zeros_like(m); sh[dd:]=m[:-dd]; t=1-dd/DEP
        col=(np.array([72,46,18])*(0.55+0.45*t)).astype(int); sel=sh&~m; o=out[:h2]; o[sel]=col
    out[:h2][m]=a[m]
    return Image.fromarray(out.astype('uint8'))
# building frames
def cut(img):
    a=np.array(img.convert('RGB')).astype(int); m=~navy(a)
    return img.convert('RGB'), Image.fromarray((m*255).astype('uint8'))
TOWER=cut(Image.open('/home/claude/pocketrts/docs/redraw_refs/clockwork_line/ref_clocktower.png'))
gp={}; exec(open('press_new.py').read().split("Z=3")[0],gp); PRESS=[cut(f) for f in gp['fr']]
gm={}; os.chdir('.'); exec(open('ms_v7.py').read().split("Z=3")[0],gm); MS=[cut(f) for f in gm['fr']]
def place(canvas,spr,cx,cy_ground,width):
    img,m=spr; k=width/img.width
    im=img.resize((int(img.width*k),int(img.height*k)),Image.LANCZOS); mm=m.resize(im.size,Image.LANCZOS)
    a=np.array(mm); ys,xs=np.nonzero(a>128); bottom=ys.max()
    canvas.paste(im,(int(cx-im.width/2),int(cy_ground-bottom)),mm)
tR=g['tR']; sR=g['sR']
frames=[]
for i in range(NF):
    r=rings(i); c=Image.new('RGB',(r.width,r.height+180),NAVY); c.paste(r,(0,180))
    b=int(i*60/110)%8
    items=[]
    items.append((cy0, 'tower', cx0))
    kinds=['press','ms','press']
    for j,(phi,d) in enumerate(zip(angles,DISTS)):
        items.append((cy0+d*math.sin(phi), kinds[j], cx0+d*math.cos(phi)))
    for y,kind,x in sorted(items):
        yg=180+y*SQ+ (tR if kind=='tower' else sR)*SQ*0.42
        if kind=='tower': place(c,TOWER,x,yg,tR*1.25)
        elif kind=='press': place(c,PRESS[b],x,yg,sR*1.45)
        else: place(c,MS[b],x,yg,sR*1.45)
    frames.append(c)
a=np.array(frames[0]).astype(int); m=~navy(a); ys,xs=np.nonzero(m)
box=(max(xs.min()-12,0),max(ys.min()-12,0),min(xs.max()+12,W),min(ys.max()+12,frames[0].height))
frames=[f.crop(box) for f in frames]
frames[0].save('base_demo.gif',save_all=True,append_images=frames[1:],duration=60,loop=0)
frames[0].save('base_demo_f0.png'); print(frames[0].size)
