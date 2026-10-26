from PIL import Image
import numpy as np, math
src=open('ms_final.py').read().split("fr=[frame(i)")[0]
src=src.replace("crank(f,d,(296,150),-t,1)","crank(f,d,(296,150),t+math.pi,1)")
src=src.replace("pos=-70+ i*20","pos=100000")
src=src.replace("if i>=4:\n        age=i-4","if i>=6:\n        age=(i-6)*2")
g={}; exec(src,g)
S=0.09
cr=Image.open('crank2.png').convert('RGB')
a=np.array(cr).astype(int); nvm=(a[...,2]>a[...,0]+25)&(a[...,2]>a[...,1]+10)
def part(box):
    c=cr.crop(box); m=Image.fromarray(((~nvm[box[1]:box[3],box[0]:box[2]])*255).astype('uint8'))
    return c,m
hub,hubm=part((540,157,905,385)); arm,armm=part((640,385,780,1020)); han,hanm=part((224,890,655,1056))
def sc(img,k,mode=Image.LANCZOS): return img.resize((max(1,int(img.width*k)),max(1,int(img.height*k))),mode)
def paste(f,img,m,x,y,flipy=False,h=None):
    if h is not None: img=img.resize((img.width,max(2,int(h))),Image.LANCZOS); m=m.resize(img.size,Image.LANCZOS)
    if flipy: img=img.transpose(Image.FLIP_TOP_BOTTOM); m=m.transpose(Image.FLIP_TOP_BOTTOM)
    f.paste(img,(int(x),int(y)),m)
def crank(f,d,piv,t,side):
    layer=Image.new('RGB',(160,160),(0,22,48)); lm=Image.new('L',(160,160),0)
    P=(80,80)                      # pivot in layer
    cosT=math.cos(t); sinT=math.sin(t)
    armfull=635*S
    # hub centre in hub crop = (715-540,275-157)
    hw,hh=sc(hub,S),None
    armS=sc(arm,S); armmS=sc(armm,S)
    handS=sc(han,S); handmS=sc(hanm,S)
    # arm: starts at pivot, visible length = cos*(700*S)
    reach=700*S*cosT
    vis=max(abs(reach),4)
    ax=P[0]-armS.width/2+ 0.25*700*S*sinT*(-1)*0   # no sway
    if reach>=0:
        paste_layers=[]
        top=P[1]
        ai=armS.resize((armS.width,int(vis)),Image.LANCZOS); am=armmS.resize(ai.size,Image.LANCZOS)
        layer.paste(ai,(int(ax),int(top)),am); lm.paste(am,(int(ax),int(top)),am)
        tipy=P[1]+reach
    else:
        ai=armS.resize((armS.width,int(vis)),Image.LANCZOS).transpose(Image.FLIP_TOP_BOTTOM); am=armmS.resize(ai.size,Image.LANCZOS).transpose(Image.FLIP_TOP_BOTTOM)
        top=P[1]-vis
        layer.paste(ai,(int(ax),int(top)),am); lm.paste(am,(int(ax),int(top)),am)
        tipy=P[1]+reach
    # handle: right end near arm centre
    hx=P[0]+(655-715)*S-handS.width+ (handS.width) - (655-224)*S
    hy=tipy-(975-890)*S
    layer.paste(handS,(int(hx),int(hy)),handmS); lm.paste(handmS,(int(hx),int(hy)),handmS)
    # hub on top
    hx0=P[0]-(715-540)*S; hy0=P[1]-(275-157)*S
    hs=sc(hub,S); hm=sc(hubm,S)
    layer.paste(hs,(int(hx0),int(hy0)),hm); lm.paste(hm,(int(hx0),int(hy0)),hm)
    if side>0:
        layer=layer.transpose(Image.FLIP_LEFT_RIGHT); lm=lm.transpose(Image.FLIP_LEFT_RIGHT)
    f.paste(layer,(int(piv[0]-80),int(piv[1]-80)),lm)
g['crank']=crank
# frame() in g calls crank(f,d,..) with global name -> overridden
from PIL import ImageDraw, ImageEnhance
WX,WY,WR=197,220,41
BOX=(WX-48,WY-48,WX+48,WY+48)
spring=g['base'].crop(BOX)
_sm=Image.new('L',(96,96),0); ImageDraw.Draw(_sm).ellipse((48-WR+2,48-WR+2,48+WR-2,48+WR-2),fill=255)
_sb=Image.new('RGB',(96,96),(28,34,48)); _sb.paste(spring,(0,0),_sm); spring=_sb
def spring_at(ang,scale):
    r=spring.rotate(-ang,resample=Image.BICUBIC,center=(48,48))
    k=scale; w=int(96*k)
    r=r.resize((w,w),Image.BICUBIC)
    out=Image.new('RGB',(96,96)); out.paste(r,((96-w)//2,(96-w)//2))
    if w<96:   # fill the rim gap with the darkest coil colour
        bg=Image.new('RGB',(96,96),(28,34,48)); m=Image.new('L',(96,96),0)
        ImageDraw.Draw(m).ellipse(((96-w)//2,(96-w)//2,(96+w)//2,(96+w)//2),fill=255)
        bg.paste(out,(0,0),m); out=bg
    return out
#           angle  scale  bright
PLAN=[(0,1.00,1.00),(18,0.97,1.04),(36,0.94,1.08),(54,0.91,1.13),(72,0.88,1.18),(90,0.85,1.24),
      None,(-25,1.03,1.10)]
def spring_frame(f,i):
    if PLAN[i] is None:   # release: fast spin back with motion blur, bulge, flash
        acc=None; n=7
        for k in range(n):
            a=90-150*k/(n-1); sc=0.85+0.27*k/(n-1)
            im=np.array(spring_at(a,sc)).astype(float)
            acc=im if acc is None else acc+im
        img=Image.fromarray((acc/n).clip(0,255).astype('uint8'))
        img=ImageEnhance.Brightness(img).enhance(1.3)
    else:
        a,sc,br=PLAN[i]; img=ImageEnhance.Brightness(spring_at(a,sc)).enhance(br)
    m=Image.new('L',(96,96),0); ImageDraw.Draw(m).ellipse((48-WR,48-WR,48+WR,48+WR),fill=255)
    f.paste(img,(BOX[0],BOX[1]),m)
    return f
def shake(f,dx,dy):
    o=Image.new('RGB',f.size,(0,22,48)); o.paste(f,(dx,dy)); return o
SP=Image.open('spring_face.png').convert('RGB')
# centre on the arbor and crop a square to the outer coil
_a=np.array(SP).astype(int); _nv=(_a[...,2]>_a[...,0]+25)&(_a[...,2]>_a[...,1]+10)&(_a.sum(2)<140)
_ys,_xs=np.nonzero(~_nv); 
SC=(618,595); SR=482
SPc=np.array(SP.crop((SC[0]-SR,SC[1]-SR,SC[0]+SR,SC[1]+SR)).resize((400,400),Image.LANCZOS)).astype(float)
BGc=np.array([6,16,34],float)
def warp(scale,rot_deg,gamma,bright):
    N=200; yy,xx=np.mgrid[0:2*N,0:2*N]; dx=xx-N+0.5; dy=yy-N+0.5
    r=np.hypot(dx,dy)/N; th=np.arctan2(dy,dx)
    Rout=scale
    rs=np.where(r<=Rout,(np.clip(r/Rout,0,1))**gamma,2.0)
    ths=th-np.radians(rot_deg)
    sx=(N+rs*N*np.cos(ths)).round().astype(int); sy=(N+rs*N*np.sin(ths)).round().astype(int)
    ok=(rs<=1.0)&(sx>=0)&(sx<2*N)&(sy>=0)&(sy<2*N)
    out=np.empty((2*N,2*N,3)); out[:]=BGc
    out[ok]=SPc[sy[ok],sx[ok]]
    # navy gaps -> dark porthole blue
    gap=(out[...,2]>out[...,0]+25)&(out.sum(2)<120); out[gap]=BGc
    out=np.clip(out*bright,0,255)
    return out
def to_patch(arr):
    return Image.fromarray(arr.astype('uint8')).resize((96,96),Image.LANCZOS)
#      scale rot gamma bright
PLAN2=[(1.00,0,1.00,1.00),(0.92,30,0.94,1.05),(0.84,60,0.88,1.10),(0.76,90,0.82,1.16),(0.69,120,0.76,1.22),(0.62,150,0.70,1.30),
       'release',(1.06,-15,1.02,1.08)]
def spring_frame(f,i):
    p=PLAN2[i]
    if p=='release':
        acc=0; n=3
        for k in range(n):
            t=k/(n-1)
            acc=acc+warp(0.9+0.28*t,90-120*t,0.85+0.25*t,1.35)
        arr=acc/n
    else:
        arr=warp(*p)
    D=2*WR+2
    img=Image.fromarray(arr.astype('uint8')).resize((D,D),Image.LANCZOS)
    m=Image.new('L',(D,D),0); ImageDraw.Draw(m).ellipse((0,0,D-1,D-1),fill=255)
    f.paste(img,(WX-D//2,WY-D//2),m)
    return f
from scipy import ndimage as ndi
_R=Image.open('cone_rings.png').convert('RGB'); _ra=np.array(_R).astype(int)
_rm=~((_ra[...,2]>_ra[...,0]+25)&(_ra[...,2]>_ra[...,1]+10)&(_ra.sum(2)<150))
_lab,_n=ndi.label(ndi.binary_closing(_rm,iterations=2))
RINGS=[]
for sl in ndi.find_objects(_lab):
    h=sl[0].stop-sl[0].start; w=sl[1].stop-sl[1].start
    if w<80: continue
    box=(sl[1].start,sl[0].start,sl[1].stop,sl[0].stop)
    RINGS.append((w,_R.crop(box),Image.fromarray((_rm[sl]*255).astype('uint8'))))
RINGS.sort(key=lambda r:-r[0]); RINGS=RINGS[:6]
K=72/RINGS[0][0]
RS=[(c.resize((max(1,int(c.width*K)),max(1,int(c.height*K))),Image.LANCZOS),m.resize((max(1,int(m.width*K)),max(1,int(m.height*K))),Image.LANCZOS)) for w,c,m in RINGS]
BASEY=WY+24
def cone(f,gap,bright=1.0):
    D=2*WR+2
    win=Image.new('RGB',(D,D),(6,16,34))
    # soft back wall shading
    d=ImageDraw.Draw(win)
    for k in range(0): d.ellipse((6+k*3,4+k*3,D-6-k*3,D-4-k*3),outline=(10+k*2,22+k*2,42+k*2))
    ox,oy=WX-D//2,WY-D//2
    for k,(c,m) in enumerate(RS):
        cy=BASEY-k*gap
        im=ImageEnhance.Brightness(c).enhance(bright)
        win.paste(im,(int(WX-c.width/2)-ox,int(cy-c.height/2)-oy),m)
    mask=Image.new('L',(D,D),0); ImageDraw.Draw(mask).ellipse((0,0,D-1,D-1),fill=255)
    f.paste(win,(ox,oy),mask)
GAPS=[10,8.2,6.4,4.6,2.9,1.3,None,12.5]
BR=[1.0,1.05,1.1,1.15,1.22,1.3,1.35,1.08]
def spring_frame(f,i):
    if GAPS[i] is None:
        acc=None
        for g_ in (2.5,7,13.5):
            t=f.copy(); cone(t,g_,BR[i]); a=np.array(t).astype(float); acc=a if acc is None else acc+a
        return Image.fromarray((acc/3).astype('uint8'))
    cone(f,GAPS[i],BR[i]); return f
fr=[]
for i in range(8):
    f=spring_frame(g['frame'](i),i)
    if i==6: f=shake(f,1,1)
    if i==7: f=shake(f,-1,0)
    fr.append(f)
Z=3; W,H=fr[0].size
sh=Image.new('RGB',(4*(W*Z+40),2*(H*Z+30)),(0,22,48))
for i,f in enumerate(fr): sh.paste(f.resize((W*Z,H*Z),Image.NEAREST),((i%4)*(W*Z+40),(i//4)*(H*Z+30)))
sh.resize((sh.width//2,sh.height//2),Image.LANCZOS).save('ms_v5_small.png')
fr[0].save('ms_v5.gif',save_all=True,append_images=fr[1:],duration=110,loop=0)
