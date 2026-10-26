"""Ticking Owl SWOOP (talons vs units), BOMB DROP (vs buildings) and DEATH guide, built in code from the painted flying
sheet (art/redraws/ticking_owl_fly.png: 5 rows S, SE, E, NE, N x 4 wing frames up, level, down, level). The pendulum
bomb (ball + chain) is cut off each frame so it can be tucked up (swoop), released (drop) or lost (death).
Frames are aligned on the red body; a code ground shadow is drawn at a fixed ground line.
Out: art/redraws/owl_swoop.png/.gif (5x6), owl_bomb.png/.gif (5x6), owl_death.png/.gif (5x6), owl_bomb_sprite.png."""
import math, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
A=np.array(Image.open('art/redraws/ticking_owl_fly.png').convert('RGB')).astype(int)
m_all=np.abs(A-NAVY).sum(2)>45
lab,n=ndi.label(ndi.binary_closing(m_all,iterations=2)); sz=ndi.sum(m_all,lab,range(1,n+1))
figs=[(k+1,s) for k,s in enumerate(ndi.find_objects(lab)) if sz[k]>5000]
# sort into rows by the red body centroid
def red_c(k,s):
    sub=A[s]; mm=(lab[s]==k)
    red=mm&(sub[...,0]>140)&(sub[...,1]<80)&(sub[...,2]<80); ys,xs=np.nonzero(red)
    return s[1].start+xs.mean(), s[0].start+ys.mean()
info=[]
for k,s in figs:
    cx,cy=red_c(k,s); info.append((cy,cx,k,s))
info.sort(); rows=[sorted(info[i*4:(i+1)*4],key=lambda t:t[1]) for i in range(5)]
def run(row,x):
    """the contiguous run of True around x in a boolean row (l, r inclusive) or None"""
    if not row[x]:
        for d in (1,-1,2,-2):
            if 0<=x+d<len(row) and row[x+d]: x=x+d; break
        else: return None
    l=x
    while l>0 and row[l-1]: l-=1
    r=x
    while r<len(row)-1 and row[r+1]: r+=1
    return l,r
SC=0.85     # these sheets are drawn at 0.85 of the flying sheet's scale so the spread wings fit 256-px cells
def part(k,s):
    sub=A[s].copy(); mm=(lab[s]==k)&m_all[s]
    R,G,B=sub[...,0],sub[...,1],sub[...,2]
    h,w=mm.shape; yy,xx=np.mgrid[0:h,0:w]
    red=mm&(R>140)&(G<80)&(B<80); ry,rx=np.nonzero(red); rbot=ry.max(); rcx=rx.mean()
    grey=mm&(R<120)&(G<120)&(B<130)&(np.abs(R-G)<24)&(np.abs(G-B)<30)&(yy>rbot-8)&(np.abs(xx-rcx)<60)
    l2,n2=ndi.label(ndi.binary_closing(grey,iterations=2))
    best=None
    for kk in range(1,n2+1):
        gy,gx=np.nonzero(l2==kk)
        if len(gy)<120: continue
        if best is None or gy.mean()>best[0]: best=(gy.mean(),gy,gx)
    _,gy,gx=best; bcx=(gx.min()+gx.max())/2; bcy=(gy.min()+gy.max())/2
    rad=max(gx.max()-gx.min(),gy.max()-gy.min())/2+3
    ball=mm&(np.hypot(xx-bcx,yy-bcy)<=rad)
    by0=int(np.nonzero(ball)[0].min()); bx=int(round(bcx))
    chain=np.zeros_like(mm); y=by0-1; ctop=by0; skip=0
    while skip<6:                 # the ball's top cap / shackle rows (wider than the chain): part of the ball
        rr=run(mm[y],bx)
        if rr is None or rr[1]-rr[0]+1<=15: break
        ball[y,rr[0]:rr[1]+1]=True; y-=1; skip+=1
    while y>0 and by0-y<46:
        rr=run(mm[y],bx)
        if rr is None or rr[1]-rr[0]+1>15: break
        chain[y,rr[0]:rr[1]+1]=True; ctop=y; y-=1
    bomb=ball|chain
    body=mm&~bomb
    # drop loose crumbs the cut leaves (bits of chain links): keep only large pieces of the body
    l3,n3=ndi.label(body); z3=ndi.sum(body,l3,range(1,n3+1))
    body&=np.isin(l3,[i+1 for i,v in enumerate(z3) if v>=60])
    def rgba(mask):
        o=np.zeros(sub.shape[:2]+(4,),np.uint8); o[...,:3]=sub; o[...,3]=mask*255
        im=Image.fromarray(o,'RGBA'); return im.resize((max(1,int(im.width*SC)),max(1,int(im.height*SC))),Image.LANCZOS)
    return dict(body=rgba(body),bomb=rgba(bomb),ball=rgba(ball),c=(rx.mean()*SC,ry.mean()*SC),pivot=(bx*SC,ctop*SC),
                btop=by0*SC,chain_len=(by0-ctop)*SC,ball_h=int(2*rad*SC))
P=[[part(k,s) for (_,_,k,s) in row] for row in rows]
Image.fromarray(np.array(P[0][1]['ball'])).crop(P[0][1]['ball'].getbbox()).save('art/redraws/owl_bomb_sprite.png')
FWD=[(0,1),(0.7,0.5),(1,0),(0.7,-0.5),(0,-1)]
CW,CH=256,204; GROUND=CH-16; HOVER=82
def shadow(cell,x,scale=1.0,alpha=150):
    sh=Image.new('RGBA',cell.size,(0,0,0,0)); d=ImageDraw.Draw(sh); rx=29*scale; ry=8*scale
    d.ellipse((x-rx,GROUND-ry,x+rx,GROUND+ry),fill=(0,6,18,alpha)); cell.alpha_composite(sh)
def dim(img,k):
    a=np.array(img).astype(float); a[...,:3]*=k; return Image.fromarray(a.clip(0,255).astype(np.uint8),'RGBA')
def draw(cell,r,col,dx=0,dy=0,ang=0,bomb='hang',bomb_dy=0,tuck=0.0,k=1.0):
    p=P[r][col]; cx,cy=p['c']; px,py=p['pivot']; PX,PY=70,40      # padding so rotated wings are never cut
    x=CW/2+dx; y=GROUND-HOVER+dy
    big=Image.new('RGBA',(p['body'].width+2*PX,p['body'].height+2*PY),(0,0,0,0))
    big.alpha_composite(p['body'],(PX,PY))
    if bomb=='hang' and bomb_dy==0:
        big.alpha_composite(p['bomb'],(PX,PY))
    elif bomb=='hang':        # a new weight lowered on a shorter chain: lift it and hide what is above the pivot
        a2=np.array(p['bomb']); a2[:max(0,int(py)-bomb_dy)] = 0
        big.alpha_composite(Image.fromarray(a2,'RGBA'),(PX,PY+bomb_dy))
    elif bomb=='tuck':        # chain wound up: the ball pulled up under the belly, between the talons
        big.alpha_composite(p['ball'],(PX,PY-int(p['chain_len'])-2))
    elif bomb=='ball':        # the chain snapped: the ball alone, falling
        big.alpha_composite(p['ball'],(PX,PY+bomb_dy))
    if ang: big=big.rotate(ang,resample=Image.BICUBIC,center=(cx+PX,cy+PY))
    if k!=1.0: big=dim(big,k)
    cell.alpha_composite(big,(int(round(x-cx-PX)),int(round(y-cy-PY))))
def build(seq,name,durs):
    cols=len(seq); cw=1536//cols
    sheet=Image.new('RGB',(1536,1024),tuple(NAVY))
    for r in range(5):
        for c,f in enumerate(seq):
            cell=Image.new('RGBA',(CW,CH),(0,0,0,0)); f(cell,r)
            cell=cell.crop(((CW-cw)//2,0,(CW-cw)//2+cw,CH))
            bg=Image.new('RGB',(cw,CH),tuple(NAVY)); bg.paste(cell,(0,0),cell); sheet.paste(bg,(c*cw,r*CH))
    sheet.save('art/redraws/%s.png'%name); g=[]
    for c in range(cols):
        o=Image.new('RGB',(5*cw,CH))
        for r in range(5): o.paste(sheet.crop((c*cw,r*CH,(c+1)*cw,(r+1)*CH)),(r*cw,0))
        g.append(o)
    g[0].save('art/redraws/%s.gif'%name,save_all=True,append_images=g[1:],duration=durs,loop=0)
# SWOOP: rise, dive (bomb wound up behind), talons strike low, climb back, level
def sw(col,dy,tilt,bomb,tuck=0,shs=1.0,fwd=0):
    def f(cell,r):
        fx,fy=FWD[r]; t=-tilt*fx if r in (1,2,3) else 0
        shadow(cell,CW/2+fx*fwd,shs); draw(cell,r,col,fx*fwd,dy+fy*fwd*0.5,t,bomb,tuck=tuck)
    return f
build([sw(1,0,0,'hang'),sw(0,-6,-8,'tuck',0,0.95,-4),sw(0,20,18,'tuck',0,1.2,10),sw(2,34,26,'tuck',0,1.35,16),
       sw(3,14,8,'tuck',0,1.15,8),sw(1,0,0,'hang',)],'owl_swoop',[140,110,80,140,110,150])
# BOMB DROP: the chain snaps, the ball falls, the owl bobs up lighter, a new weight is lowered
def bd(col,dy,bomb,bomb_dy=0):
    def f(cell,r): shadow(cell,CW/2,1.0); draw(cell,r,col,0,dy,0,bomb,bomb_dy)
    return f
build([bd(1,0,'hang'),bd(0,-2,'ball',8),bd(2,-8,'ball',34),bd(3,-6,'none'),bd(0,-3,'hang',-16),bd(1,0,'hang')],
      'owl_bomb',[140,90,110,130,120,150])
# DEATH guide: jolt, spin, fall, crash flat, still
def de(col,ang,dy,sx,lying=False,k=1.0,bomb='hang'):
    def f(cell,r):
        side=1 if r<3 else -1; shadow(cell,CW/2+sx*side,1.0+0.6*min(1,max(dy,0)/60),150+20*lying)
        if not lying: draw(cell,r,col,sx*side,dy,ang*side,bomb,k=k); return
        p=P[r][col]; img=p['body']; img=img.crop(img.getbbox()); img=img.resize((img.width,max(4,int(img.height*0.5))),Image.LANCZOS)
        if k!=1.0: img=dim(img,k)
        x=CW/2+sx*side; top=GROUND+4-img.height; cell.alpha_composite(img,(int(x-img.width/2),int(top)))
        ball=P[r][col]['ball']; bb=ball.crop(ball.getbbox())
        if k!=1.0: bb=dim(bb,k)
        cell.alpha_composite(bb,(int(x+side*img.width*0.42-bb.width/2),int(GROUND-bb.height+2)))
    return f
build([de(1,0,0,0),de(0,30,6,4,bomb='ball'),de(2,110,30,10,bomb='ball'),de(1,200,56,16,bomb='ball'),
       de(2,0,0,22,True,0.9),de(2,0,0,22,True,0.75)],'owl_death',[120,90,80,80,160,900])
print('ok')
