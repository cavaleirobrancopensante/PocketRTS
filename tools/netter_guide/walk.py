"""Netter WALK in code from ChatGPT's direction sheet (art/redraws/netter_dirs.png, rows S, SE, E, NE, N; same crops
as fire.py). A trot: the four stubby legs step in diagonal pairs (right-front with left-back, then left-front with
right-back); a foot in the air lifts and swings forward, a foot on the ground slides back at a steady speed (planted
while the unit moves); the drum dips a little each time a pair lands.
Each visible leg (hand-set boxes per row, split where legs touch by growing seeds through the paint): the big hip ball (with its brass ring) rides with the drum and is drawn on
top; below it the steel shin leans (a shear: its bottom follows the foot, its top stays in the ball) and slides into
the foot when it lifts; the brass foot stays flat; the small ankle ball is drawn on top of the joint. The legs hidden
under the drum (seen only by their feet) just move. "Forward" on screen per row: side view across, front and back
views a hair down or up (there the trot is mostly feet lifting).
Out: art/redraws/netter_walk.png/.gif (5 rows x 8 frames, cells 307 x 204 like netter_fire.png)."""
import math, numpy as np
from PIL import Image
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
A=np.array(Image.open('art/redraws/netter_dirs.png').convert('RGB')).astype(int)
FULL=[(302,21,562,213),(324,224,561,394),(303,409,575,565),(307,579,544,767),(314,780,547,963)]
CW,CH=307,204; N=8; PAD=20
STEP=8.0         # a foot travels +-STEP px forward/back of its hip (side view)
LIFT=8.0         # how high a stepping foot lifts
BOB=2.0          # the drum dips when a pair lands
FWD=[(0.0,0.17),(0.7,0.12),(1.0,0.0),(0.7,-0.12),(0.0,-0.17)]
# per row, per leg: role (r/l = the unit's right/left, f/b = front/back), kind (near: hip ball shows; far: tucked
# under the drum, only its foot shows), box (x0,y0,x1,y1) of its lower part, hip ball (x,y,disk r), ankle ball (x,y,r),
# where the brass foot starts. Coordinates in fire.py's crop (pad 2).
LEGS=[
 [dict(role='rb',kind='far',box=(63,148,102,196)),
  dict(role='lb',kind='far',box=(163,148,201,196)),
  dict(role='rf',kind='near',box=(0,145,63,196),hip=(41.5,145,16),ankle=(49,167,5),foot=170),
  dict(role='lf',kind='near',box=(201,145,264,196),hip=(221.5,144.5,16),ankle=(215,167,5),foot=170)],
 [dict(role='lb',kind='far',box=(58,121,108,174)),
  dict(role='lf',kind='near',box=(190,119,241,174),hip=(210,118.5,15),ankle=(205,137,4),foot=139),
  dict(role='rb',kind='near',box=(0,120,58,174),hip=(37,120,15),ankle=(44,138,4),foot=141),
  dict(role='rf',kind='near',box=(138,132,190,174),hip=(165,132,16),ankle=(154,149,4),foot=152)],
 [dict(role='lb',kind='far',box=(60,118,98,160)),
  dict(role='lf',kind='far',box=(164,118,196,160)),
  dict(role='rb',kind='near',box=(0,115,62,160),hip=(41.5,115.5,16),ankle=(48,134,4),foot=137),
  dict(role='rf',kind='near',box=(196,115,276,160),hip=(211.5,115.5,16),ankle=(206,134,4),foot=137)],
 [dict(role='lf',kind='far',box=(140,136,183,192)),
  dict(role='lb',kind='near',box=(0,129,62,192),hip=(39.5,129,15),ankle=(45,150,4),foot=152),
  dict(role='rf',kind='near',box=(183,127,241,192),hip=(202.5,127.5,15),ankle=(198,150,4),foot=152),
  dict(role='rb',kind='near',box=(62,141,140,192),hip=(97,141,17),ankle=None,foot=160)],
 [dict(role='lf',kind='far',box=(63,138,100,187)),
  dict(role='rf',kind='far',box=(140,138,172,187)),
  dict(role='lb',kind='near',box=(0,132,63,187),hip=(45.5,132.5,16),ankle=(54,157,5),foot=160),
  dict(role='rb',kind='near',box=(172,132,237,187),hip=(192,132.5,16),ankle=(186,155,4),foot=158)],
]
PHASE={'rf':0.0,'lb':0.0,'lf':0.5,'rb':0.5}      # diagonal pairs

def crop(box,pad=2):
    x0,y0,x1,y1=box; c=A[y0-pad:y1+pad,x0-pad:x1+pad]; m=np.abs(c-NAVY).sum(2)>45; return c,m
def piece(F,mask):
    H,W=mask.shape; o=np.zeros((H+2*PAD,W+2*PAD,4),np.uint8)
    o[PAD:PAD+H,PAD:PAD+W,:3]=np.clip(F,0,255); o[PAD:PAD+H,PAD:PAD+W,3]=mask*255
    return Image.fromarray(o,'RGBA')
def place(img,p0,p1,M):
    """draw img (padded) so that p0 lands on p1 and the rest follows matrix M about it"""
    Mi=np.linalg.inv(M); a,b=Mi[0]; d,e=Mi[1]
    P0=(p0[0]+PAD,p0[1]+PAD); P1=(p1[0]+PAD,p1[1]+PAD)
    return img.transform(img.size,Image.AFFINE,(a,b,P0[0]-a*P1[0]-b*P1[1],d,e,P0[1]-d*P1[0]-e*P1[1]),
                         resample=Image.NEAREST)
def shift(img,dx,dy): return place(img,(0,0),(dx,dy),np.eye(2))

def assign(F,FM,legs,shrink=7):
    """split the legs where they touch: each leg's box seeds its middle, then the seeds grow through the paint one
    pixel at a time (near legs first), so a boundary follows where the feet actually meet, not a straight box edge"""
    H,W=FM.shape; yy,xx=np.mgrid[0:H,0:W]
    reg=np.zeros((H,W),bool); lab=np.zeros((H,W),int)
    for i,L in enumerate(legs):
        x0,y0,x1,y1=L['box']
        if L['kind']=='near': y0=int(L['hip'][1])
        b=FM&(xx>=x0)&(xx<x1)&(yy>=y0)&(yy<y1); reg|=b
        lab[b&(xx>=x0+shrink)&(xx<x1-shrink)&(yy>=y0+shrink)&(lab==0)]=i+1
    order=sorted(range(len(legs)),key=lambda i:legs[i]['kind']!='near')
    st=ndi.generate_binary_structure(2,1)
    for _ in range(80):
        free=reg&(lab==0)
        if not free.any(): break
        new=lab.copy()
        for i in order: new[ndi.binary_dilation(lab==i+1,st)&free&(new==0)]=i+1
        if (new==lab).all(): break
        lab=new
    return lab

ROWS=[]
for r in range(5):
    F,FM=crop(FULL[r]); H,W=FM.shape
    yy,xx=np.mgrid[0:H,0:W]
    lab=assign(F,FM,LEGS[r])
    taken=np.zeros_like(FM); legs=[]
    for i,L in enumerate(LEGS[r]):
        region=lab==i+1
        d=dict(L)
        if L['kind']=='near':
            hx,hy,hr=L['hip']
            disk=FM&(np.hypot(xx-hx,yy-hy)<=hr)
            low=region&~disk&(yy>=hy)
            ank=np.zeros_like(FM)
            if L['ankle']:
                ax,ay,ar=L['ankle']; ank=low&(np.hypot(xx-ax,yy-ay)<=ar+0.5)
            d.update(ball=piece(F,disk),shin=piece(F,low&~ank&(yy<L['foot'])),footimg=piece(F,low&~ank&(yy>=L['foot'])),
                     ankleimg=piece(F,ank))
            taken|=disk|low
        else:
            d.update(img=piece(F,region)); taken|=region
        legs.append(d)
    ROWS.append(dict(body=piece(F,FM&~taken),legs=legs,size=(W,H)))

def foot(p):
    """forward offset and lift of a foot at phase p: on the ground from 0 (in front) to 0.5 (behind), then a step"""
    p%=1.0
    if p<0.5: return STEP*(1-4*p),0.0
    t=(p-0.5)/0.5
    return -STEP+STEP*(1-math.cos(math.pi*t)),LIFT*math.sin(math.pi*t)

def frame(r,q):
    R=ROWS[r]; W,H=R['size']; fx,fy=FWD[r]
    bob=BOB*(1+math.cos(4*math.pi*q))/2
    cv=Image.new('RGBA',(W+2*PAD,H+2*PAD),(0,0,0,0))
    def offs(L):
        f,h=foot(q+PHASE[L['role']]); return f*fx,f*fy-h
    for L in R['legs']:
        if L['kind']=='far':
            dx,dy=offs(L); cv.alpha_composite(shift(L['img'],dx,dy))
    cv.alpha_composite(shift(R['body'],0,bob))
    for L in sorted([L for L in R['legs'] if L['kind']=='near'],key=lambda L:L['hip'][1]):
        dx,dy=offs(L); hx,hy,_=L['hip']
        k=dx/max(4.0,L['foot']-hy)                      # the shin leans: top in the ball, bottom with the foot
        cv.alpha_composite(place(L['shin'],(hx,hy),(hx,hy+bob),np.array([[1.0,k],[0.0,1.0]])))
        cv.alpha_composite(shift(L['footimg'],dx,dy))
        cv.alpha_composite(shift(L['ankleimg'],dx,dy))
        cv.alpha_composite(shift(L['ball'],0,bob))
    cell=Image.new('RGB',(CW,CH),tuple(NAVY))
    cell.paste(cv,((CW-cv.width)//2,CH-cv.height+8),cv); return cell

if __name__=='__main__':
    sheet=Image.new('RGB',(N*CW,5*CH),tuple(NAVY))
    for r in range(5):
        for c in range(N): sheet.paste(frame(r,c/N),(c*CW,r*CH))
    sheet.save('art/redraws/netter_walk.png'); g=[]
    for c in range(N):
        o=Image.new('RGB',(5*CW,CH))
        for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
        g.append(o)
    g[0].save('art/redraws/netter_walk.gif',save_all=True,append_images=g[1:],duration=110,loop=0)
    print('ok')
