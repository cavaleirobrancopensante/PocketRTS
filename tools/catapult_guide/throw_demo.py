"""Spring Catapult THROW demo from ChatGPT's concept (art/redraws/concepts/catapult_v1.png): ChatGPT drew the arm
forward in both the loaded and the firing pose, so the arm (beam and cup) is cut off the firing frame and swung in
code about its hinge over the spring drum: wound back low with a curled Clock Soldier in the cup, it whips forward,
the soldier flies off in an arc, the arm knocks against its stop strut and is wound back. A look-and-motion demo for
the owner, not game art. Out: art/redraws/catapult_throw_demo.gif (+ .png strip)."""
import math, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
A=np.array(Image.open('art/redraws/concepts/catapult_v1.png').convert('RGB')).astype(int)
def rgba(a,m):
    o=np.zeros(a.shape[:2]+(4,),np.uint8); o[...,:3]=np.clip(a,0,255); o[...,3]=m*255; return Image.fromarray(o,'RGBA')
# the firing frame (empty cup), and the flying soldier
X0,Y0,X1,Y1=510,280,940,780
F=A[Y0:Y1,X0:X1]; FM=np.abs(F-NAVY).sum(2)>45
H,W=FM.shape; yy,xx=np.mgrid[0:H,0:W]
P=(222.0,205.0)            # the arm's hinge (blue ball over the spring drum)
J=(300.0,95.0)             # the cup's joint
def seg_dist(px,py,a,b):
    ax,ay=a; bx,by=b; vx,vy=bx-ax,by-ay; t=np.clip(((px-ax)*vx+(py-ay)*vy)/(vx*vx+vy*vy),0,1)
    return np.hypot(px-(ax+t*vx),py-(ay+t*vy))
beam=seg_dist(xx,yy,P,J)<=22
cup=(xx>=278)&(xx<=375)&(yy>=12)&(yy<=95)
hinge=np.hypot(xx-P[0],yy-P[1])<=19
# light blue speed lines are not the arm
Fr,Fg,Fb=F[...,0],F[...,1],F[...,2]
streak=(Fb>Fr+40)&(Fb>140)&(Fr<150)&~(np.hypot(xx-300,yy-95)<14)
arm=FM&(beam|cup)&~hinge&~(streak&~beam)
lab,n=ndi.label(arm)
if n>1:
    sz=ndi.sum(arm,lab,range(1,n+1)); arm&=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=60])
base=FM&~arm&~(streak&(yy<180))
thin=base&~ndi.binary_opening(base,structure=np.ones((3,3)))&(yy<235)   # 1-2 px speed lines touching the machine
base&=~thin
lab,n=ndi.label(base)                       # the speed lines left over the machine: not attached to it
if n>1:
    sz=ndi.sum(base,lab,range(1,n+1)); base&=lab==(int(np.argmax(sz))+1)
# fill the hole the arm leaves over the machine with the neighbouring paint
k=np.ones((9,9)); dens=ndi.convolve(base.astype(float),k,mode='constant')/k.sum()
fill=arm&(dens>0.5)
_,(iy,ix)=ndi.distance_transform_edt(~base,return_indices=True)
Fb2=F.copy(); Fb2[fill]=F[iy[fill],ix[fill]]
base_img=rgba(Fb2,base|fill); arm_img=rgba(F,arm); hinge_img=rgba(F,FM&hinge)
# the flying soldier (isolated at the top right of the concept)
S=A[205:310,955:1085]; SM=np.abs(S-NAVY).sum(2)>45
Sr,Sg,Sb=S[...,0],S[...,1],S[...,2]
SM&=~((Sb>Sr+40)&(Sb>140)&(Sr<150)&(Sg>110))      # drop the speed lines
lab,n=ndi.label(SM); sz=ndi.sum(SM,lab,range(1,n+1)); SM&=lab==(int(np.argmax(sz))+1)
sold=rgba(S,SM).crop(rgba(S,SM).getbbox())
sold=sold.resize((int(sold.width*0.62),int(sold.height*0.62)),Image.LANCZOS)   # curled up it fits the cup
CUP=(325.0,48.0)           # the cup's middle (where the soldier sits)
CW,CH=620,640; OX,OY=170,110
SEQ=[(118,'in'),(118,'in'),(96,'in'),(52,'in'),(4,'out'),(-6,'out'),(0,'out'),(26,None),(58,None),(90,None),(118,None)]
DUR=[500,160,60,50,60,70,90,140,140,140,300]
def rot_pt(p,ang):
    a=math.radians(-ang); c,s=math.cos(a),math.sin(a); dx,dy=p[0]-P[0],p[1]-P[1]
    return (P[0]+c*dx-s*dy,P[1]+s*dx+c*dy)
frames=[]; fly_t=0
for i,(ang,load) in enumerate(SEQ):
    cv=Image.new('RGBA',(CW,CH),(0,0,0,0))
    big=Image.new('RGBA',(CW,CH),(0,0,0,0)); big.alpha_composite(arm_img,(OX,OY))
    armr=big.rotate(ang,resample=Image.NEAREST,center=(P[0]+OX,P[1]+OY))
    behind=ang>60                 # wound back, the arm and cup sit behind the drum
    if behind: cv.alpha_composite(armr)
    cv.alpha_composite(base_img,(OX,OY))
    if not behind: cv.alpha_composite(armr)
    cv.alpha_composite(hinge_img,(OX,OY))
    if load=='in':
        c=rot_pt(CUP,ang); cv.alpha_composite(sold,(int(c[0]+OX-sold.width/2),int(c[1]+OY-sold.height*0.75)))
    elif load=='out':
        fly_t+=1
    if fly_t and i>=4:
        t=(i-4+1)*0.16                 # it keeps flying across the following frames
        c=rot_pt(CUP,4); x=c[0]+OX+t*420; y=c[1]+OY-t*260+t*t*180
        if x<CW-10: cv.alpha_composite(sold,(int(x-sold.width/2),int(y-sold.height/2)))
    cell=Image.new('RGB',(CW,CH),tuple(NAVY)); cell.paste(cv,(0,0),cv); frames.append(cell)
frames[0].save('art/redraws/catapult_throw_demo.gif',save_all=True,append_images=frames[1:],duration=DUR,loop=0)
strip=Image.new('RGB',(5*CW//2,2*CH//2),tuple(NAVY))
for i,f in enumerate(frames[:10]): strip.paste(f.resize((CW//2,CH//2)),((i%5)*(CW//2),(i//5)*(CH//2)))
strip.save('art/redraws/catapult_throw_demo.png')
print('ok',len(frames))
