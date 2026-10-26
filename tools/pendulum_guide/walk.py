"""Pendulum WALK in code from the same painted direction sheet (via anim.py's cut-out body, pendulum and hub): the legs
are cut off at the hip balls; each leg swings about its hip (a stiff stride, strongest in the side views) and lifts
by sliding its shin up into the thigh (a telescoping mechanical knee); the body dips when both feet are down and rocks
over the standing leg; the pendulum lags behind the rocking. The side view's far leg walks half a step behind.
Out: art/redraws/pendulum_walk.png/.gif (5 rows x 8 frames, cells 204 x 307 like pendulum_idle.png)."""
import math, numpy as np
from PIL import Image
from scipy import ndimage as ndi
exec(open('tools/pendulum_guide/anim.py').read().split("CW,CH=204,307")[0])
CW,CH=204,307
# per row: [(hip x, hip y, knee y), ...] from the blue balls; swing amplitude (deg); rocking (px)
LEGS=[([(52,179,231),(158,179,231)],4,3),
      ([(56,161,208),(148,159,205)],9,2),
      ([(46,162,219)],16,0),
      ([(54,150,206),(144,155,212)],9,2),
      ([(48,170,227),(148,170,228)],4,3)]
LIFT=11
def comp_at(mask,x,y):
    lab,n=ndi.label(mask)
    k=lab[y,x]
    if k==0:
        ys,xs=np.nonzero(mask); i=int(np.argmin((xs-x)**2+(ys-y)**2)); k=lab[ys[i],xs[i]]
    return lab==k
LEGDATA=[]
for r in range(5):
    R=ROWS[r]; B=np.array(R['body']); bm=B[...,3]>0; H,W=bm.shape
    legs=[]; rest=bm.copy()
    for (hx,hy,ky) in LEGS[r][0]:
        below=bm.copy(); below[:hy-12]=False
        lm=comp_at(below,hx,hy)
        rest&=~lm
        img=B.copy(); img[...,3]=lm*255
        lower=img.copy(); lower[:ky-4,:,3]=0                 # the shin and foot (from just above the knee ball's middle)
        upper=img.copy(); upper[ky-4:,:,3]=0
        legs.append(dict(upper=Image.fromarray(upper,'RGBA'),lower=Image.fromarray(lower,'RGBA'),hip=(hx,hy)))
    body=B.copy(); body[...,3]=rest*255
    LEGDATA.append(dict(body=Image.fromarray(body,'RGBA'),legs=legs))
def leg_img(L,lift,ang,size,shade=1.0):
    W,H=size; c=Image.new('RGBA',(W,H),(0,0,0,0))
    c.alpha_composite(L['upper']); c.alpha_composite(L['lower'],(0,-int(round(lift))))
    if shade!=1.0:
        a=np.array(c).astype(float); a[...,:3]*=shade; c=Image.fromarray(a.clip(0,255).astype(np.uint8),'RGBA')
    if ang: c=c.rotate(ang,resample=Image.NEAREST,center=L['hip'])
    return c
def frame(r,p):
    R=ROWS[r]; D=LEGDATA[r]; W,H=R['size']; pad=140; amp,rock=LEGS[r][1],LEGS[r][2]
    s=math.sin(2*math.pi*p)
    bob=int(round(2*(1-abs(s))))                      # down when both feet are on the ground
    bx=int(round(rock*s))                             # rock over the standing leg
    def place(img,dx=0,dy=0):
        c=Image.new('RGBA',(W+2*pad,H+2*pad),(0,0,0,0)); c.paste(img,(pad+dx,pad+dy)); return c
    phases=[p,p+0.5]
    legimgs=[]
    for i,L in enumerate(D['legs']):
        q=phases[i]; lift=LIFT*max(0.0,math.sin(2*math.pi*q))
        ang=amp*math.cos(2*math.pi*q)*(1 if r!=2 else -1)
        legimgs.append(leg_img(L,lift,ang,(W,H)))
    far=None
    if r==2:      # the side view's far leg: the same leg, darker, half a step behind
        q=p+0.5; lift=LIFT*max(0.0,math.sin(2*math.pi*q)); ang=-amp*math.cos(2*math.pi*q)
        far=leg_img(D['legs'][0],lift,ang,(W,H),FARLEG['shade'])
    pend_ang=-7*s if r in (0,4) else -9*math.cos(2*math.pi*p)
    piece=place(R['piece'],bx,bob).rotate(pend_ang,resample=Image.NEAREST,center=(R['pivot'][0]+pad+bx,R['pivot'][1]+pad+bob))
    cv=Image.new('RGBA',(W+2*pad,H+2*pad),(0,0,0,0))
    if far is not None: cv.alpha_composite(place(far,FARLEG['dx'],FARLEG['dy']))
    if BEHIND[r]:
        cv.alpha_composite(piece); cv.alpha_composite(place(D['body'],bx,bob))
        for li in legimgs: cv.alpha_composite(place(li))
    else:
        cv.alpha_composite(place(D['body'],bx,bob))
        for li in legimgs: cv.alpha_composite(place(li))
        cv.alpha_composite(piece); cv.alpha_composite(place(R['hub'],bx,bob))
    cell=Image.new('RGB',(CW,CH),tuple(NAVY)); x=(CW-cv.width)//2; y=CH-H-8-pad
    cell.paste(cv,(x,y),cv); return cell
N=8
sheet=Image.new('RGB',(N*CW,5*CH),tuple(NAVY))
for r in range(5):
    for c in range(N): sheet.paste(frame(r,c/N),(c*CW,r*CH))
sheet.save('art/redraws/pendulum_walk.png'); g=[]
for c in range(N):
    o=Image.new('RGB',(5*CW,CH))
    for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
    g.append(o)
g[0].save('art/redraws/pendulum_walk.gif',save_all=True,append_images=g[1:],duration=150,loop=0)
print('ok')
