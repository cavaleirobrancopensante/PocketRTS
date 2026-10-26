"""Jack ATTACK UP (shooting at flyers, owner: it must raise its arm): the painted idle frame with the launcher arm cut out
and raised (rotated about the shoulder or elbow) toward the sky, then the same small recoil along the raised barrel as
the ground attack. Holes the arm leaves on the body are filled from neighbouring body pixels.
Out: art/redraws/jack_attack_up_body.png (5 rows x 6 frames, cells 256 x 204.8, placed like jack_attack_body.png),
art/redraws/jack_attack_up.gif, art/redraws/jack_attack_up_tips.json (the drill tip per row in cell pixels, for the
muzzle burst and the screw's start)."""
import json, math, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
im=Image.open('art/redraws/jack_idle.png').convert('RGB')
BOX=[(159,23,306,181),(174,216,299,360),(170,387,301,537),(166,571,308,713),(164,743,308,873)]
# per row: arm polygon, pivot, raise angle (PIL degrees, + = counter-clockwise), the drill tip at rest
ARM=[([(20,57),(47,57),(47,78),(33,100),(21,126),(0,126),(0,92),(10,70)],(39,60),-105,(5,115)),
     ([(14,57),(40,57),(40,80),(28,100),(18,122),(0,122),(0,92),(6,70)],(31,60),-128,(4,116)),
     ([(50,76),(136,76),(136,101),(50,101)],(55,88),48,(131,92)),
     ([(88,55),(143,70),(143,100),(110,100),(88,72)],(92,58),88,(140,92)),
     ([(96,44),(144,62),(144,98),(118,98),(96,62)],(100,46),96,(141,90))]
REC=[0,3,2,1,0,0]
CW,CH=256,204
def rgba(a,m):
    o=np.zeros(a.shape[:2]+(4,),np.uint8); o[...,:3]=np.clip(a,0,255); o[...,3]=m*255; return Image.fromarray(o,'RGBA')
sheet=Image.new('RGB',(1536,1024),tuple(NAVY)); tips={}
for r,b in enumerate(BOX):
    F=np.array(im.crop(b)).astype(int); M=np.abs(F-NAVY).sum(2)>45; h,w=M.shape
    poly,piv,ang,tip=ARM[r]
    pm=Image.new('L',(w,h),0); ImageDraw.Draw(pm).polygon(poly,fill=255); arm=(np.array(pm)>0)&M
    body=M&~arm
    k=np.ones((9,9)); dens=ndi.convolve(body.astype(float),k,mode='constant')/k.sum()
    fill=arm&(dens>0.5)
    _,(iy,ix)=ndi.distance_transform_edt(~body,return_indices=True)
    Fb=F.copy(); Fb[fill]=F[iy[fill],ix[fill]]
    BODY=rgba(Fb,body|fill); ARMI=rgba(F,arm)
    P=60
    def big(img):
        c=Image.new('RGBA',(w+2*P,h+2*P),(0,0,0,0)); c.paste(img,(P,P)); return c
    arm_up=big(ARMI).rotate(ang,resample=Image.NEAREST,center=(piv[0]+P,piv[1]+P))
    # where the drill tip goes, and the barrel direction after the raise
    th=math.radians(-ang); vx,vy=tip[0]-piv[0],tip[1]-piv[1]
    tx=piv[0]+vx*math.cos(th)-vy*math.sin(th); ty=piv[1]+vx*math.sin(th)+vy*math.cos(th)
    L=math.hypot(tx-piv[0],ty-piv[1]); dx,dy=(tx-piv[0])/L,(ty-piv[1])/L
    for c in range(6):
        cv=Image.new('RGBA',(w+2*P,h+2*P),(0,0,0,0))
        if r>=3: cv.alpha_composite(arm_up); cv.alpha_composite(big(BODY))     # seen from behind: the raised arm goes behind the head
        else: cv.alpha_composite(big(BODY)); cv.alpha_composite(arm_up)
        ox=(CW-w)//2-int(round(dx*REC[c])); oy=CH-h-10-int(round(dy*REC[c]*0.5))
        cell=Image.new('RGB',(CW,CH),tuple(NAVY)); cell.paste(cv,(ox-P,oy-P),cv)
        sheet.paste(cell,(c*CW,r*CH))
        if c==1: tips[['S','SE','E','NE','N'][r]]=[round(ox+tx,1),round(oy+ty,1),round(dx,3),round(dy,3)]
sheet.save('art/redraws/jack_attack_up_body.png')
json.dump({'cell':[CW,CH],'note':'drill tip on the fire frame (frame 2) in cell pixels, then the barrel direction','tips':tips},open('art/redraws/jack_attack_up_tips.json','w'),indent=1)
g=[]
for c in range(6):
    o=Image.new('RGB',(5*CW,CH))
    for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
    g.append(o)
g[0].save('art/redraws/jack_attack_up.gif',save_all=True,append_images=g[1:],duration=[220,70,80,90,110,220],loop=0)
print(tips)
