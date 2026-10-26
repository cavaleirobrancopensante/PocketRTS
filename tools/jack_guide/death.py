"""Jack DEATH from the painted idle frame: the jack-in-the-box breaks: the spring flings the body up and off, the body
tumbles and lands on its side next to the base, the empty spring wobbles and droops. Out: art/redraws/jack_death.png
(5 rows x 7 frames) and .gif. Pose guide for a ChatGPT clean-up (falls are safe to clean up: everything moves)."""
import math, numpy as np
from PIL import Image
NAVY=np.array([0,22,48])
im=np.array(Image.open('art/redraws/jack_idle.png').convert('RGB')).astype(int)
BOX=[(159,23,306,181),(174,216,299,360),(170,387,301,537),(166,571,308,713),(164,743,308,873)]
SPR=[(86,133,52,104),(84,122,40,88),(97,128,42,92),(82,120,43,92),(78,110,43,88)]
FALL=[-1,-1,1,1,1]
CW,CH=1536//7,1024//5
def rgba(F,M):
    o=np.zeros(F.shape[:2]+(4,),np.uint8); o[...,:3]=F; o[...,3]=M*255; return Image.fromarray(o,'RGBA')
def dark(img,k):
    a=np.array(img).astype(float); a[...,:3]*=k; return Image.fromarray(a.clip(0,255).astype(np.uint8),'RGBA')
#        body dx, body dy, body angle, spring stretch, spring tilt
SEQ=[(0,0,0,1.0,0),(0,-5,0,1.2,0),(12,-12,25,1.35,0),(32,-4,70,1.15,12),(50,0,95,0.9,-8),(52,-5,88,1.0,14),(52,0,92,0.85,22)]
sheet=Image.new('RGB',(1536,1024),tuple(NAVY))
for r,(x0,y0,x1,y1) in enumerate(BOX):
    F=im[y0:y1,x0:x1]; M=np.abs(F-NAVY).sum(2)>45; h,w=M.shape
    st,bt,sx0,sx1=SPR[r]
    yy,xx=np.mgrid[0:h,0:w]
    springm=M&(yy>=st)&(((xx>=sx0)&(xx<sx1))|(yy>=bt))
    bodym=M&~springm
    BODY=rgba(F,bodym); SPRING=rgba(F,springm)
    for c,(bx,by,ba,sk,stl) in enumerate(SEQ):
        cell=Image.new('RGBA',(CW,CH),(0,0,0,0))
        gx=(CW-w)//2-FALL[r]*34; gy=CH-h-12         # the base sits off-centre, the body lands on the other side
        # spring: stretch the coil band (st..bt) keeping the plate, then tilt about the plate centre
        sp=np.array(SPRING); band=sp[st:bt]; plate=sp[bt:]
        nb=max(4,int(round((bt-st)*sk)))
        band2=np.array(Image.fromarray(band,'RGBA').resize((w,nb),Image.NEAREST))
        canvas=np.zeros((nb+plate.shape[0]+40,w,4),np.uint8)
        canvas[40:40+nb]=band2; canvas[40+nb:]=plate
        S2=Image.fromarray(canvas,'RGBA').rotate(-stl*FALL[r],resample=Image.BICUBIC,center=((sx0+sx1)/2,canvas.shape[0]-4),expand=False)
        if c==6: S2=dark(S2,0.8)
        cell.alpha_composite(S2,(gx,gy+h-canvas.shape[0]))
        # body: thrown up and sideways, tumbling; lands lying on its side next to the base
        ys,xs=np.nonzero(bodym); bcx=(xs.min()+xs.max())/2; bcy=(ys.min()+ys.max())/2
        B2=BODY.crop((int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1))
        B2=B2.rotate(-ba*FALL[r],resample=Image.BICUBIC,expand=True)
        if c==6: B2=dark(B2,0.8)
        B2=B2.crop(B2.getbbox())
        cx=gx+bcx+FALL[r]*bx; ground=gy+h-4
        if c>=4:
            cy=ground-B2.height/2+by
        else:
            cy=gy+bcy+by
        cell.alpha_composite(B2,(int(round(cx-B2.width/2)),int(round(cy-B2.height/2))))
        bg=Image.new('RGB',(CW,CH),tuple(NAVY)); bg.paste(cell,(0,0),cell); sheet.paste(bg,(c*CW,r*CH))
sheet.save('art/redraws/jack_death.png')
g=[]
for c in range(7):
    o=Image.new('RGB',(5*CW,CH))
    for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
    g.append(o)
g[0].save('art/redraws/jack_death.gif',save_all=True,append_images=g[1:],duration=[150,80,90,90,110,110,900],loop=0)
print('ok')
