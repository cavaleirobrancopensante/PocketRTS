"""Pendulum WALK in code (v3: long strides, the pendulum drives the gait) from the painted direction sheet, via
anim.py's cut-out body, pendulum and hub.
- Each leg = thigh (hip ball to knee), shin (knee ball and the red skirt) and foot (the brass dome and sole), cut at
  the blue balls and where the skirt meets the dome; the hip ball rides with the body. A two-bone IK (hip to ankle,
  the knee bends forward) puts the foot on a long stride: a standing foot stays FLAT and slides back at a steady
  speed (planted while the unit moves), a stepping foot lifts, dangles toe-down and lands flat again.
- The stride is 3D-ish: each row projects "forward" on screen (side view: across; front and back views: a little
  down or up; there the bones stretch or shorten along their length instead of turning).
- The body dips when both feet are down (a heavy stomp; the same dip in every row, set by the side view), sways
  over the standing leg, leans a little into the walk. The pendulum swings side to side (slower than the attack) and
  drives the legs (owner, 2026-10-26): as it swings right the screen-left leg steps forward, as it swings left the
  screen-right one. Seen from the side that swing goes towards us and away (owner: make it clear it goes all the way
  to the other side): on the far side it is darker, shorter (tilted away) and drawn behind the legs; on our side it
  is lit, longer and drawn in front of everything, and it comes to our side when the near leg is back, so it is
  clear of the leg.
Out: art/redraws/pendulum_walk.png/.gif (5 rows x 8 frames, cells 204 x 307 like pendulum_idle.png)."""
import math, numpy as np
from PIL import Image
from scipy import ndimage as ndi
exec(open('tools/pendulum_guide/anim.py').read().split("CW,CH=204,307")[0])
CW,CH=204,307; N=8; PAD=140
A_STEP=45.0      # a foot travels +-A_STEP px forward/back of the hip (side view px)
LIFT=19.0        # how high the stepping foot lifts
HEEL=10.0        # a foot lands heel first, toe up (deg, side view)
PUSH=14.0        # and pushes off with its heel lifted (deg)
SWING=22.0       # the pendulum's swing while walking (deg; the attack goes to 62)
SIDE_DEPTH=0.55  # side view: how much a pendulum swung towards us drops on screen (and one swung away rises)
FAR_DARK=0.38    # side view: how much darker it gets on the far side
LEAN=2.5         # body leans into the walk (side view, deg)
ROCK=3.0         # body sways over the standing leg (front view, px)
ROLL=1.5         # and tilts with it (deg)
DEPTH=0.17       # screen y per px of forward motion towards/away from the camera (S: the front foot drops 7.7 px)
FWD=[(0.0,DEPTH),(0.28,0.7*DEPTH),(1.0,0.0),(0.28,-0.7*DEPTH),(0.0,-DEPTH)]   # "forward" on screen per row
# (the painted 3/4 views hold their legs side by side like the front view, so their stride is mostly up/down too:
#  a full sideways stride there made the legs do the splits)
SIDE=[-1.0,-0.7,0.0,0.7,1.0]     # the unit's RIGHT leg: on screen left (-) or right (+), and the sway's share
PSIGN=[1,1,-1,-1,-1]             # pendulum swing direction while the right leg steps (see the docstring)
LEANK=[0.0,0.7,1.0,0.7,0.0]
FAR_SHADE=FARLEG['shade']; FAR_OFF=(FARLEG['dx'],FARLEG['dy'])

def comp_at(mask,x,y):
    lab,n=ndi.label(mask)
    k=lab[y,x]
    if k==0:
        ys,xs=np.nonzero(mask); i=int(np.argmin((xs-x)**2+(ys-y)**2)); k=lab[ys[i],xs[i]]
    return lab==k
def blue_balls(B):
    R_,G_,Bc,Aa=[B[...,i].astype(int) for i in range(4)]
    blue=(Aa>0)&(Bc>R_+40)&(Bc>110)
    lab,n=ndi.label(blue); out=[]
    for i,s in enumerate(ndi.find_objects(lab)):
        m=lab==i+1
        if m.sum()<40: continue
        ys,xs=np.nonzero(m)
        out.append(dict(x=float(xs.mean()),y=float(ys.mean()),r=max(s[0].stop-s[0].start,s[1].stop-s[1].start)/2.0))
    return out
def padded(img,W,H):
    c=Image.new('RGBA',(W+2*PAD,H+2*PAD),(0,0,0,0)); c.paste(img,(PAD,PAD)); return c
def shade(img,k):
    a=np.array(img).astype(float); a[...,:3]*=k; return Image.fromarray(a.clip(0,255).astype(np.uint8),'RGBA')
def ankle_row(B,lm,ky,sy):
    """where the red skirt ends and the brass dome begins"""
    R_,G_,Bc=[B[...,i].astype(int) for i in range(3)]
    red=lm&(R_>140)&(G_<90); brass=lm&(R_>120)&(G_>70)&(Bc<90)&~red
    for y in range(int(ky)+15,sy):
        nb,nr=int(brass[y].sum()),int(red[y].sum())
        if nb>=8 and nb>nr*1.2: return y
    return int(sy-20)

LEGDATA=[]
for r in range(5):
    R=ROWS[r]; B=np.array(R['body']); bm=B[...,3]>0; H,W=bm.shape
    balls=sorted(blue_balls(B),key=lambda b:b['y'])
    nl=1 if r==2 else 2
    hips=sorted(balls[:nl],key=lambda b:b['x']); knees=sorted(balls[nl:2*nl],key=lambda b:b['x'])
    yy,xx=np.mgrid[0:H,0:W]
    legs=[]; rest=bm.copy()
    for hb,kb in zip(hips,knees):
        hx,hy,kx,ky=hb['x'],hb['y'],kb['x'],kb['y']
        below=bm.copy(); below[:int(hy)-12]=False
        lm=comp_at(below,int(hx),int(hy)); rest&=~lm
        ys,xs=np.nonzero(lm); sy=int(ys.max())
        ay=ankle_row(B,lm,ky,sy)
        hipd=np.hypot(xx-hx,yy-hy)<=hb['r']+2
        kned=np.hypot(xx-kx,yy-ky)<=kb['r']+2
        thigh=lm&~hipd&~kned&(yy<ky)
        shin=lm&~hipd&((yy>=ky)|kned)&(yy<ay)
        foot=lm&(yy>=ay)
        axs=np.nonzero(shin[ay-1])[0]; ax=float(axs.mean()) if len(axs) else kx
        bys,bxs=np.nonzero(lm&(yy>=sy-4))
        heel=(float(bxs.min()),float(sy)); toe=(float(bxs.max()),float(sy))   # facing right (side views)
        def img(m):
            o=B.copy(); o[...,3]=m*255; return padded(Image.fromarray(o,'RGBA'),W,H)
        legs.append(dict(hip=(hx,hy),knee=(kx,ky),ankle=(ax,float(ay)),sole=(float(bxs.mean()),float(sy)),heel=heel,toe=toe,
                         thigh=img(thigh),shin=img(shin),foot=img(foot),hipball=img(lm&hipd)))
    body=B.copy(); body[...,3]=rest*255
    ha=np.array(R['hub'])[...,3]>0; px=int(round(R['pivot'][0]))
    hb=np.nonzero(ha[:,max(0,px-2):px+3].any(1))[0]          # the rod shows from under the hub's bottom edge
    LEGDATA.append(dict(body=padded(Image.fromarray(body,'RGBA'),W,H),legs=legs,size=(W,H),
                        piece=padded(R['piece'],W,H),hub=padded(R['hub'],W,H),
                        rodtop=float(hb.max()) if len(hb) else R['pivot'][1]))

def foot(q):
    """forward offset, lift and foot turn (deg, + = toe down) of a foot at gait phase q: 0 = lands in front on its
    heel, flat by mid-stance, the heel lifts as it pushes off (0.5 = toe-off), then it swings forward in the air"""
    q%=1.0
    if q<0.5:
        f=A_STEP*(1-4*q)
        phi=-HEEL*(1-q/0.25)**2 if q<0.25 else PUSH*((q-0.25)/0.25)**2
        return f,0.0,phi
    t=(q-0.5)/0.5
    return -A_STEP+A_STEP*(1-math.cos(math.pi*t)),LIFT*math.sin(math.pi*t**0.8),PUSH*(1-t)**2-HEEL*t*t
def ik(F,D,l1,l2,stretch):
    d=math.hypot(F,D)
    k=1.0
    if d>(l1+l2)*0.9995:
        if stretch: k=d/((l1+l2)*0.9995)
        else: d=(l1+l2)*0.9995
    l1,l2=l1*k,l2*k
    d=max(abs(l1-l2)+1e-3,d)
    a=math.acos(max(-1.0,min(1.0,(l1*l1+d*d-l2*l2)/(2*l1*d))))
    th=math.atan2(F,D)+a                     # the knee bends forward
    kF,kD=l1*math.sin(th),l1*math.cos(th)
    vx,vy=F-kF,D-kD; n=math.hypot(vx,vy) or 1.0
    return (kF,kD),(kF+vx/n*l2,kD+vy/n*l2)
def rotm(rot):
    c,s=math.cos(rot),math.sin(rot); return np.array([[c,-s],[s,c]])
def matrix(v0,v1):
    """turn v0 onto v1 and stretch along it (the bone keeps its width)"""
    rot=math.atan2(v1[1],v1[0])-math.atan2(v0[1],v0[0])
    n0=math.hypot(*v0); u=np.array(v0)/n0
    return rotm(rot)@(np.eye(2)+(math.hypot(*v1)/n0-1)*np.outer(u,u))
def place(img,p0,p1,M):
    """draw img (padded) so that p0 lands on p1 and the rest follows matrix M about it"""
    Mi=np.linalg.inv(M); a,b=Mi[0]; d,e=Mi[1]
    P0=(p0[0]+PAD,p0[1]+PAD); P1=(p1[0]+PAD,p1[1]+PAD)
    return img.transform(img.size,Image.AFFINE,(a,b,P0[0]-a*P1[0]-b*P1[1],d,e,P0[1]-d*P1[0]-e*P1[1]),
                         resample=Image.NEAREST)
def sub(a,b): return (a[0]-b[0],a[1]-b[1])
def add(a,b): return (a[0]+b[0],a[1]+b[1])

def foot_place(L,r,f,h,phi_deg):
    """where the ankle goes and how the foot turns: on the ground the foot rocks on its heel or toe (that corner
    stays put), in the air it follows the sole's path; the side view centres the stride under the hip"""
    fx,fy=FWD[r]
    phi=math.radians(phi_deg)*fx                      # only the side views see the foot turn
    shift=(L['hip'][0]-L['ankle'][0]) if r==2 else 0.0
    dx,dy=shift+f*fx,f*fy
    if h==0.0 and phi!=0.0:
        piv=L['toe'] if phi>0 else L['heel']
        v=rotm(phi)@np.array(sub(L['ankle'],piv))
        return (piv[0]+dx+v[0],piv[1]+dy+v[1]),phi
    v=rotm(phi)@np.array(sub(L['sole'],L['ankle']))
    return (L['sole'][0]+dx-v[0],L['sole'][1]+dy-h-v[1]),phi
def leg_pose(L,r,hip_s,f,h,phi_deg):
    """knee and ankle on screen, the foot's turn, and the thigh's and shin's matrices.
    Side view: a two-bone IK, the knee bends forward. Front, back and 3/4 views: the knee bend would point at the
    camera and squash the painted shin, so there the shin and foot slide up and down instead (a telescoping knee:
    the knee ball rides up over the thigh) and the thigh turns (and stretches, never shrinks) to follow"""
    ank_t,phi=foot_place(L,r,f,h,phi_deg)
    if r==2:
        t0=sub(L['knee'],L['hip']); s0=sub(L['ankle'],L['knee'])
        (kF,kD),(aF,aD)=ik(ank_t[0]-hip_s[0],ank_t[1]-hip_s[1],math.hypot(*t0),math.hypot(*s0),False)
        knee=(hip_s[0]+kF,hip_s[1]+kD); ank=(hip_s[0]+aF,hip_s[1]+aD)
        return knee,ank,phi,matrix(t0,sub(knee,hip_s)),matrix(s0,sub(ank,knee))
    off=sub(ank_t,L['ankle']); knee=add(L['knee'],off)
    T0=sub(L['knee'],L['hip']); T1=sub(knee,hip_s)
    n0,n1=math.hypot(*T0),math.hypot(*T1)
    if n1<n0: T1=(T1[0]*n0/n1,T1[1]*n0/n1)
    return knee,ank_t,phi,matrix(T0,T1),np.eye(2)

# the body's dip, from the side view: how low the hip must come so both standing legs reach the ground
_E=LEGDATA[2]['legs'][0]
_E_L=math.hypot(*sub(_E['knee'],_E['hip']))+math.hypot(*sub(_E['ankle'],_E['knee']))
def dip(q):
    d=0.0
    for p in (q,q+0.5):
        f,h,phi=foot(p)
        if h==0.0:
            a,_=foot_place(_E,2,f,h,phi)
            dx=a[0]-_E['hip'][0]
            d=max(d,a[1]-math.sqrt(max(1.0,(0.99*_E_L)**2-dx*dx))-_E['hip'][1])
    return d

def frame(r,q):
    D=LEGDATA[r]; R=ROWS[r]; W,H=D['size']; legs=D['legs']
    s=math.sin(2*math.pi*q)
    phases=[q] if r==2 else ([q,q+0.5] if SIDE[r]<0 else [q+0.5,q])     # the right leg has phase q
    bob=dip(q); bx=SIDE[r]*ROCK*s
    Mb=rotm(math.radians(LEAN*LEANK[r]+SIDE[r]*ROLL*s))
    piv=(sum(L['hip'][0] for L in legs)/len(legs),sum(L['hip'][1] for L in legs)/len(legs))
    def body_pt(p):
        v=Mb@np.array(sub(p,piv)); return (piv[0]+bx+v[0],piv[1]+bob+v[1])
    cv=Image.new('RGBA',(W+2*PAD,H+2*PAD),(0,0,0,0))
    def draw_leg(L,ph,off=(0,0),dark=None):
        Ls=dict(L,**{k:add(L[k],off) for k in ('hip','knee','ankle','sole','heel','toe')})
        hip_s=body_pt(Ls['hip'])
        f,h,phi=foot(ph)
        knee,ank,phi,Mt,Ms=leg_pose(Ls,r,hip_s,f,h,phi)
        parts=[place(L['thigh'],L['hip'],hip_s,Mt),
               place(L['shin'],L['knee'],knee,Ms),
               place(L['foot'],L['ankle'],ank,rotm(phi)),
               place(L['hipball'],L['hip'],hip_s,Mb)]
        for p in parts: cv.alpha_composite(shade(p,dark) if dark else p)
    hub=body_pt(R['pivot'])
    if r==2:
        # side view: the swing is towards us (+) and away (-); our side when the near (right) leg is back (q=0.5)
        lat=-math.radians(SWING)*math.cos(2*math.pi*q); sl=math.sin(lat)
        M=np.array([[1+0.06*sl,0.0],[0.0,math.cos(lat)+SIDE_DEPTH*sl]])
        # stretch it from where the rod comes out under the body (the body keeps the rod's top: no gap opens)
        top=(R['pivot'][0],D['rodtop']); pend=place(D['piece'],top,body_pt(top),M)
        if sl<0: pend=shade(pend,1-FAR_DARK*(-sl/math.sin(math.radians(SWING))))
        depth=sl/math.sin(math.radians(SWING))
    else:
        theta=PSIGN[r]*SWING*math.cos(2*math.pi*q)        # PIL sense: + = the bob goes right
        pend=place(D['piece'],R['pivot'],hub,rotm(math.radians(-theta)))
    bodyimg=place(D['body'],piv,(piv[0]+bx,piv[1]+bob),Mb)
    hubimg=place(D['hub'],piv,(piv[0]+bx,piv[1]+bob),Mb)
    order=sorted(range(len(legs)),key=lambda i:legs[i]['hip'][1])     # the higher hip is further away
    if r==2:
        if depth<-0.3: cv.alpha_composite(pend)                          # away from us: behind everything
        draw_leg(legs[0],q+0.5,FAR_OFF,FAR_SHADE)                        # the far (left) leg
        cv.alpha_composite(bodyimg)
        if -0.3<=depth<=0.3: cv.alpha_composite(pend)                     # in the middle: between the legs
        cv.alpha_composite(hubimg)
        draw_leg(legs[0],q)
        if depth>0.3: cv.alpha_composite(pend); cv.alpha_composite(hubimg)   # on our side: in front of the leg
    elif BEHIND[r]:
        cv.alpha_composite(pend)
        for i in order: draw_leg(legs[i],phases[i])
        cv.alpha_composite(bodyimg)
    else:
        for i in order: draw_leg(legs[i],phases[i])
        cv.alpha_composite(bodyimg); cv.alpha_composite(pend); cv.alpha_composite(hubimg)
    cell=Image.new('RGB',(CW,CH),tuple(NAVY)); x=(CW-cv.width)//2; y=CH-H-8-PAD
    cell.paste(cv,(x,y),cv); return cell

if __name__=='__main__':
    sheet=Image.new('RGB',(N*CW,5*CH),tuple(NAVY))
    for r in range(5):
        for c in range(N): sheet.paste(frame(r,c/N),(c*CW,r*CH))
    sheet.save('art/redraws/pendulum_walk.png'); g=[]
    for c in range(N):
        o=Image.new('RGB',(5*CW,CH))
        for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
        g.append(o)
    g[0].save('art/redraws/pendulum_walk.gif',save_all=True,append_images=g[1:],duration=140,loop=0)
    print('ok')
