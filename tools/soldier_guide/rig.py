"""Clock Soldier cut-out rig: the body from the painted idle sheet, the legs built from ChatGPT's painted parts sheet
(art/redraws/clock_soldier_parts.png: thigh, knee, shin, foot per direction), rotated at hip and knee in code.
walk(r, p) -> RGB frame for direction row r at gait phase p (0..1)."""
import math, numpy as np
from PIL import Image
exec(open('tools/soldier_guide/walk_guide.py').read().split("W,H=1536,1024")[0])
PS=np.array(Image.open('art/redraws/clock_soldier_parts.png').convert('RGB')).astype(int)
def part(box):
    x0,y0,x1,y1=box; c=PS[y0:y1,x0:x1]; m=np.abs(c-NAVY).sum(2)>45
    rgba=np.zeros(c.shape[:2]+(4,),np.uint8); rgba[...,:3]=c; rgba[...,3]=m*255
    return Image.fromarray(rgba,'RGBA')
THIGH={'front':part((107,30,157,181)),'side':part((105,410,158,545))}
SHIN={'front':part((577,39,620,187)),'side':part((576,408,621,549))}
KNEE=part((345,82,398,141))
FEET=[part((822,76,901,154)),part((807,263,897,343)),part((807,465,901,532)),part((807,634,902,709)),part((818,835,882,920))]
# per direction: lateral swing factor, depth sign (toward the camera = +), which part set
DIR=[(0.0,1.0,'front'),(0.65,0.6,'side'),(1.0,0.0,'side'),(0.65,-0.6,'side'),(0.0,-1.0,'front')]
TH,BEND=24.0,42.0
def setup(r):
    box,hip,split,far,_=ROWS[r]
    x0,y0,x1,y1=box; F=im[y0:y1,x0:x1]; M=np.abs(F-NAVY).sum(2)>45
    X=excl_mask(M.shape,EXCL[r]); body=M.copy(); body[hip:,:]&=X[hip:,:]; M2=M&~X
    legL=np.zeros_like(M); legL[hip:,:split]=M2[hip:,:split]
    legR=np.zeros_like(M); legR[hip:,split:]=M2[hip:,split:]
    def hipx(lm):
        ys,xs=np.nonzero(lm[hip:hip+10]); return xs.mean() if len(xs) else split
    ground=max(np.nonzero(legL)[0].max(),np.nonzero(legR)[0].max())
    width=19.0
    SP=[30,24,8,24,30][r]; CX=[0,6,-2,0,0][r]
    ys,xs=np.nonzero(M[hip-30:hip]); cx=(xs.min()+xs.max())/2+CX if False else (hipx(legL)+hipx(legR))/2+CX
    return F,body,cx-SP/2,cx+SP/2,hip,ground,width,far
def place_seg(canvas,img,top,vec,width,dark):
    L=math.hypot(*vec)
    if L<1: return
    k=width/img.width; im2=img.resize((max(1,int(round(img.width*k))),max(1,int(round(L)))),Image.LANCZOS)
    if dark: im2=Image.fromarray((np.array(im2)*np.array([0.8,0.8,0.8,1.0])).astype(np.uint8),'RGBA')
    ang=math.degrees(math.atan2(vec[0],vec[1]))
    S=int(2*L+2*im2.width+4); c=Image.new('RGBA',(S,S),(0,0,0,0)); c.alpha_composite(im2,(S//2-im2.width//2,S//2))
    c=c.rotate(ang,resample=Image.BICUBIC,center=(S//2,S//2))
    canvas.alpha_composite(c,(int(round(top[0]-S//2)),int(round(top[1]-S//2))))
def leg_draw(canvas,hx,hy,ph,r,lenT,lenS,width,dark,dy0):
    kx,d,kind=DIR[r]
    t1=math.radians(TH*math.cos(2*math.pi*ph)); bend=math.radians(BEND*max(0.0,-math.sin(2*math.pi*ph)))
    t2=t1-bend
    def vec(l,t): return (l*math.sin(t)*kx, l*math.cos(t)+d*l*math.sin(t)*0.3)
    v1=vec(lenT,t1); kn=(hx+v1[0],hy+dy0+v1[1]); v2=vec(lenS,t2); an=(kn[0]+v2[0],kn[1]+v2[1])
    place_seg(canvas,THIGH[kind],(hx,hy+dy0),v1,width,dark)
    place_seg(canvas,SHIN[kind],kn,v2,width*0.92,dark)
    kw=int(width*1.25); kimg=KNEE.resize((kw,kw),Image.LANCZOS)
    if dark: kimg=Image.fromarray((np.array(kimg)*np.array([0.8,0.8,0.8,1.0])).astype(np.uint8),'RGBA')
    canvas.alpha_composite(kimg,(int(kn[0]-kw/2),int(kn[1]-kw/2)))
    f=FEET[r]; fw=width*1.9; fimg=f.resize((int(fw),int(fw*f.height/f.width)),Image.LANCZOS)
    if dark: fimg=Image.fromarray((np.array(fimg)*np.array([0.8,0.8,0.8,1.0])).astype(np.uint8),'RGBA')
    canvas.alpha_composite(fimg,(int(an[0]-fimg.width/2),int(an[1]-fimg.height*0.35)))
    return an[1]+fimg.height*0.65
def walk(r,p):
    F,body,hl,hr,hip,ground,width,far=setup(r)
    Lg=ground-hip; lenT=Lg*0.34; lenS=Lg*0.30
    h,w=body.shape; P=20
    def render(dy0):
        cv=Image.new('RGBA',(w+2*P,h+2*P),(0,0,0,0))
        legs=[('L',hl,p),('R',hr,p+0.5)]
        if far: legs.sort(key=lambda t:0 if t[0]==far else 1)
        lows=[]
        for name,hx,ph in legs:
            lows.append(leg_draw(cv,hx+P,hip+P,ph,r,lenT,lenS,width,bool(far) and name==far,dy0))
        rgba=np.zeros((h,w,4),np.uint8); rgba[...,:3]=F; rgba[...,3]=body*255
        cv.alpha_composite(Image.fromarray(rgba,'RGBA'),(P,P+int(round(dy0))))
        return cv,max(lows)
    _,low=render(0)
    cv,_=render((ground+P)-low)
    out=Image.new('RGB',cv.size,tuple(NAVY)); out.paste(cv,(0,0),cv)
    return out
if __name__=='__main__':
    W,H=1536,1024; CW,CH=W//6,H//5
    sheet=Image.new('RGB',(W,H),tuple(NAVY)); gifs=[]
    for c in range(6):
        row=[]
        for r in range(5):
            f=walk(r,c/6.0); sheet.paste(f,(c*CW+(CW-f.width)//2,r*CH+(CH-f.height)//2)); row.append(f)
        g=Image.new('RGB',(5*230,230),tuple(NAVY)); [g.paste(f,(i*230+(230-f.width)//2,(230-f.height)//2)) for i,f in enumerate(row)]
        gifs.append(g)
    sheet.save('art/redraws/clock_soldier_walk_rig.png')
    gifs[0].save('art/redraws/clock_soldier_walk_rig.gif',save_all=True,append_images=gifs[1:],duration=140,loop=0)
    print('ok')
