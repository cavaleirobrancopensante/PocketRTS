"""Pendulum DEATH guide in code (for a ChatGPT clean-up), from the walk's cut-out parts (walk.py): the legs give way
(they crumple down onto the ground), the tower body sinks onto them and topples over sideways, the pendulum swings
loose, snaps off and falls flat, the body hits the ground, bounces once and lies still with a few loose cogs.
Rows S, SE, E (part 1) and NE, N (part 2) as two 1536 x 1024 guide images (6 frames of 256 x 307 per row), so each
fits one ChatGPT request at the unit's own scale. Out: art/redraws/pendulum_death_guide_1.png, _2.png and .gif."""
import math, numpy as np
from PIL import Image, ImageDraw
exec(open('tools/pendulum_guide/walk.py').read().split("if __name__=='__main__':")[0])
DW,DH=256,307
FALL=[1,1,1,1,-1]                        # screen side it topples to, per row
SQUASH=[1.0,0.80,0.48,0.30,0.28,0.28]    # legs: height share left
TILT=[0,5,18,52,90,88]                   # body: degrees towards FALL
BOUNCE=[0,0,0,0,-5,0]
PEND=[-20,30,48,None,None,None]          # pendulum: swing while attached (deg), then it is off
DARK=[1,1,1,1,0.92,0.82]

def layer(img,W,H):
    """crop a padded piece back to the row's own box"""
    return img.crop((PAD,PAD,PAD+W,PAD+H))
def legs_rest(r):
    D=LEGDATA[r]; W,H=D['size']; cv=Image.new('RGBA',(W+2*PAD,H+2*PAD),(0,0,0,0))
    def draw(L,off=(0,0),dark=None):
        for k in ('thigh','shin','foot','hipball'):
            p=L[k] if off==(0,0) else place(L[k],(0,0),off,np.eye(2))
            cv.alpha_composite(shade(p,dark) if dark else p)
    if r==2: draw(D['legs'][0],FAR_OFF,FAR_SHADE)
    for L in D['legs']: draw(L)
    return cv
def gear(d,cx,cy,rad,teeth=8,col=(196,150,60)):
    pts=[]
    for i in range(teeth*2):
        a=math.pi*i/teeth; rr=rad if i%2==0 else rad*0.72
        pts.append((cx+rr*math.cos(a),cy+rr*math.sin(a)))
    d.polygon(pts,fill=col,outline=(60,40,20)); d.ellipse((cx-rad*0.3,cy-rad*0.3,cx+rad*0.3,cy+rad*0.3),fill=(70,50,30))

def frame(r,k):
    D=LEGDATA[r]; R=ROWS[r]; W,H=D['size']; fall=FALL[r]
    ground=max(L['sole'][1] for L in D['legs'])
    hip_y=min(L['hip'][1] for L in D['legs'])
    cv=Image.new('RGBA',(DW*2,DH*2),(0,0,0,0)); ox=DW-W//2; oy=DH*2-8-H-(DH-0)  # unit box in the big canvas
    oy=DH*2-DH-8-(H-ground)                                                    # ground lands at cell bottom - 8
    oy=DH*2-8-int(ground)-DH//2*0
    # legs: crumple down onto the ground, spreading a little
    s=SQUASH[k]; legs=legs_rest(r)
    M=np.array([[1+(1-s)*0.35,0.0],[0.0,s]])
    cx=W/2
    legs=place(legs,(cx,ground),(cx,ground),M)
    # body (with the hub): sinks with the legs, then tips over about its bottom corner on the falling side
    body=Image.new('RGBA',legs.size,(0,0,0,0)); body.alpha_composite(D['body']); body.alpha_composite(D['hub'])
    drop=(1-s)*(ground-hip_y)
    xs=[L['hip'][0] for L in D['legs']]
    corner=((max(xs)+18) if fall>0 else (min(xs)-18),hip_y)
    a=math.radians(TILT[k])*fall
    lie_shift=(-fall*0.55*(corner[0]-W/2) if fall>0 else -fall*0.55*(W/2-corner[0]))*min(1.0,TILT[k]/90.0)
    piv_new=(corner[0]-fall*abs(lie_shift),corner[1]+drop+BOUNCE[k])
    bodyimg=place(body,corner,piv_new,rotm(a))
    # once it has tipped past the legs, it lands: centred a little to the falling side, resting on the ground
    bb=bodyimg.getbbox()
    if bb and k>=3:
        tx=W/2+fall*16; ty=ground+BOUNCE[k]-(16 if k==3 else 0)
        bodyimg=place(bodyimg,(0,0),(tx-((bb[0]+bb[2])/2-PAD),ty-(bb[3]-PAD)),np.eye(2))
    elif bb and bb[3]-PAD>ground+2:
        bodyimg=place(bodyimg,(0,0),(0,ground+2-(bb[3]-PAD)),np.eye(2))
    # pendulum: swings loose on its hub, then snaps off and falls flat in front
    hub=R['pivot']
    def body_pt(p):
        v=rotm(a)@np.array(sub(p,corner)); return (piv_new[0]+v[0],piv_new[1]+v[1])
    if PEND[k] is not None:
        pend=place(D['piece'],hub,body_pt(hub),rotm(math.radians(-PEND[k]*fall)))
    else:
        pa=np.array(D['piece'])[...,3]>0; ys,xs2=np.nonzero(pa)
        c=((xs2.mean()-PAD),(ys.mean()-PAD)); L=(ys.max()-ys.min())
        ang=[None,None,None,62,90,92][k]
        land=(W/2-fall*34+[0,0,0,fall*6,0,0][k],ground-[0,0,0,40,12,10][k])
        pend=place(D['piece'],c,land,rotm(math.radians(ang*-fall)))
    cv2=Image.new('RGBA',legs.size,(0,0,0,0))
    behind=BEHIND[r]
    if behind: cv2.alpha_composite(pend)
    cv2.alpha_composite(legs); cv2.alpha_composite(bodyimg)
    if not behind: cv2.alpha_composite(pend)
    if k>=4:      # loose cogs and a spring on the ground
        d=ImageDraw.Draw(cv2)
        gx=W/2+fall*30+PAD
        for (dx,dy,rr) in [(-38,-6,7),(22,-4,5),(48,-9,6)]:
            gear(d,gx+dx*(1 if k==5 else 0.8),PAD+ground+dy-(6 if k==4 else 0),rr)
    if DARK[k]!=1: cv2=shade(cv2,DARK[k])
    cell=Image.new('RGB',(DW,DH),tuple(NAVY))
    bx=(DW-W)//2-PAD; by=DH-8-int(round(ground))-PAD
    cell.paste(cv2,(bx,by),cv2)
    return cell

if __name__=='__main__':
    frames={r:[frame(r,k) for k in range(6)] for r in range(5)}
    for part,rows in ((1,[0,1,2]),(2,[3,4])):
        g=Image.new('RGB',(1536,1024),tuple(NAVY))
        for i,r in enumerate(rows):
            for k in range(6): g.paste(frames[r][k],(k*DW,i*(DH+20)))
        g.save('art/redraws/pendulum_death_guide_%d.png'%part)
    gif=[]
    for k in range(6):
        o=Image.new('RGB',(5*DW,DH),tuple(NAVY))
        for r in range(5): o.paste(frames[r][k],(r*DW,0))
        gif.append(o)
    gif[0].save('art/redraws/pendulum_death_guide.gif',save_all=True,append_images=gif[1:],duration=[160,110,100,100,140,900],loop=0)
    print('ok')
