"""Clock Soldier ATTACK built in code from the painted idle frames: the sword arm (shoulder, arm, sword) is cut out and
swung about the shoulder (wind-up, strike, recover); what the arm hid on the body is filled from nearby painted pixels.
Out: art/redraws/clock_soldier_attack.png (5 rows x 6 frames) and .gif."""
import math, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
im=np.array(Image.open('art/redraws/clock_soldier_idle.png').convert('RGB')).astype(int)
BOXES=[(163,28,338,192),(186,222,326,388),(197,409,317,566),(184,599,339,756),(177,791,337,954)]
# per row: pivot, arm polygon, sword line (x0,y0,x1,y1,w), wind-up angle, strike angle (degrees, PIL: + = counter-clockwise)
ROW=[((50,58),[(28,60),(62,60),(62,104),(48,104),(48,166),(0,166),(0,92)],None,-55,25),
     ((26,56),[(0,62),(46,62),(46,100),(30,104),(30,126),(0,126)],(16,110,72,168,9),-60,30),
     ((45,54),[(30,64),(64,64),(66,110),(40,110)],(54,104,120,150,8),70,-35),
     ((92,54),[(84,62),(116,62),(126,96),(122,112),(98,112),(86,100)],(114,102,154,146,8),60,-30),
     ((115,52),[(108,62),(140,62),(147,110),(118,113),(110,95)],(130,104,162,155,8),55,-25)]
LEAN=[(0,2),(2,1),(3,0),(2,-1),(0,-2)]
def poly_mask(shape,pts):
    m=Image.new('L',(shape[1],shape[0]),0); ImageDraw.Draw(m).polygon(pts,fill=255); return np.array(m)>0
def line_mask(shape,ln):
    x0,y0,x1,y1,w=ln; h,ww=shape; yy,xx=np.mgrid[0:h,0:ww]; dx,dy=x1-x0,y1-y0; L2=dx*dx+dy*dy
    t=np.clip(((xx-x0)*dx+(yy-y0)*dy)/L2,0,1); return np.hypot(xx-(x0+t*dx),yy-(y0+t*dy))<w
PAD=40
def frames_row(r):
    x0,y0,x1,y1=BOXES[r]; F=im[y0:y1,x0:x1]
    Fp=np.zeros((F.shape[0]+2*PAD,F.shape[1]+2*PAD,3),int); Fp[:]=NAVY; Fp[PAD:PAD+F.shape[0],PAD:PAD+F.shape[1]]=F
    M=np.abs(Fp-NAVY).sum(2)>45
    piv,poly,sw,wa,sa=ROW[r]
    pts=[(x+PAD,y+PAD) for x,y in poly]
    arm=poly_mask(M.shape,pts)
    if sw: arm|=line_mask(M.shape,(sw[0]+PAD,sw[1]+PAD,sw[2]+PAD,sw[3]+PAD,sw[4]))
    arm&=M
    if r==1:   # the near leg stays a leg, only the sword crossing it goes with the arm
        leg=np.zeros_like(arm); leg[104+PAD:,20+PAD:64+PAD]=True
        gold=(Fp[...,0]>170)&(Fp[...,1]>120)&(Fp[...,2]<120)
        thin=line_mask(M.shape,(19+PAD,114+PAD,69+PAD,163+PAD,4.5))
        arm&=~(leg&~thin)
    rest=M&~arm
    lab,n=ndi.label(rest)
    if n>1:
        sz=ndi.sum(rest,lab,range(1,n+1))
        for k,z in enumerate(sz,1):
            if z<80: arm|=lab==k; rest&=lab!=k
    hull=ndi.binary_closing(rest,iterations=6)&~ndi.binary_erosion(np.zeros_like(rest))
    hole=arm&hull
    base=Fp.copy(); base[arm]=NAVY
    if hole.any():
        _,(iy,ix)=ndi.distance_transform_edt(~rest,return_indices=True)
        base[hole]=Fp[iy[hole],ix[hole]]
    restm=rest|hole
    rgba=np.zeros(Fp.shape[:2]+(4,),np.uint8); rgba[...,:3]=Fp; rgba[...,3]=arm*255
    ARM=Image.fromarray(rgba,'RGBA'); P=(piv[0]+PAD,piv[1]+PAD)
    seq=[0,0.55*wa,wa,sa,0.6*sa,0.2*sa]
    lean=[0,-0.4,-0.6,1.0,0.7,0.2]
    out=[]
    for a,l in zip(seq,lean):
        f=np.zeros_like(Fp); f[:]=NAVY
        dx=int(round(LEAN[r][0]*l)); dy=int(round(LEAN[r][1]*l))
        sh=np.roll(np.roll(restm,dy,0),dx,1); bs=np.roll(np.roll(base,dy,0),dx,1); f[sh]=bs[sh]
        img=Image.fromarray(f.astype(np.uint8))
        a2=ARM.rotate(a,resample=Image.NEAREST,center=P,translate=(dx,dy))
        img.paste(a2,(0,0),a2)
        out.append(img)
    return out
if __name__=='__main__':
    W,H=1536,1024; CW,CH=W//6,H//5
    sheet=Image.new('RGB',(W,H),tuple(NAVY)); rows=[]
    for r in range(5):
        fr=frames_row(r); rows.append(fr)
        for c,f in enumerate(fr):
            ff=f
            sheet.paste(ff,(c*CW+(CW-ff.width)//2,r*CH+(CH-ff.height)//2))
    sheet.save('art/redraws/clock_soldier_attack.png')
    g=[]
    for c in range(6):
        o=Image.new('RGB',(5*CW,CH),tuple(NAVY))
        for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
        g.append(o)
    g[0].save('art/redraws/clock_soldier_attack.gif',save_all=True,append_images=g[1:],duration=[110,110,160,90,110,140],loop=0)
    print('ok')
