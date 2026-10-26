"""Netter DEATH guide in code (for a ChatGPT clean-up), from the walk's cut-out parts (walk.py) and the fire's cannon
cut (fire.py's CUT lines): it is knocked back, its four stubby legs give way and splay out flat, the drum slams down
onto the ground and rolls a little, the spring cannon is thrown off its collar and lands on its side beside the drum,
and it lies still. 5 rows (S, SE, E, NE, N) x 5 frames of 307 x 204 in one 1536 x 1024 guide.
Out: art/redraws/netter_death_guide.png and .gif."""
import math, numpy as np
from PIL import Image
exec(open('tools/netter_guide/walk.py').read().split("if __name__=='__main__':")[0])
CUT=[(57,[]),(43,[(168,216,50)]),(41,[(165,276,44)]),(51,[(110,161,56)]),(54,[])]
SIDE=[1,1,-1,-1,1]               # the side the cannon is thrown to (away from where it points, roughly)
SPLAY=[0,8,18,20,20]             # legs: how far the feet slide out
SQUASH=[1.0,0.8,0.42,0.4,0.4]    # legs: height share left
DROP=[0,6,0,0,0]                 # drum: extra drop before it lands (it lands on the flattened legs)
TILT=[-4,6,-3,9,8]               # drum: rocks back from the hit, then settles tipped a little
GUN=[(12,-4,0),(40,-18,14),(95,-20,40),(None,0,62),(None,0,62)]   # cannon: turn (deg), lift (px), sideways (px)
GUN_REST=[80,160,170,160,80]     # how it lies on the ground per row (a barrel seen end-on tips onto its side)
DARK=[1,1,1,0.92,0.82]

def rot(t): c,s=math.cos(t),math.sin(t); return np.array([[c,-s],[s,c]])
def frame(r,k):
    R=ROWS[r]; W,H=R['size']; side=SIDE[r]
    body=np.array(R['body']).copy()                     # the drum, collar and cannon (no legs)
    lim=np.full(W,CUT[r][0])
    for x0,x1,y in CUT[r][1]: lim[x0:x1]=y
    yy=np.arange(body.shape[0])[:,None]-PAD; xx=np.arange(body.shape[1])[None,:]-PAD
    gunm=(body[...,3]>0)&(yy<lim[np.clip(xx,0,W-1)])&(xx>=0)&(xx<W)
    gun=body.copy(); gun[...,3]=gunm*255; drum=body.copy(); drum[...,3]=((body[...,3]>0)&~gunm)*255
    gun=Image.fromarray(gun,'RGBA'); drum=Image.fromarray(drum,'RGBA')
    near=[L for L in R['legs'] if L['kind']=='near']; far=[L for L in R['legs'] if L['kind']=='far']
    ground=float(max(np.nonzero(np.array(R['body'])[...,3].any(1))[0].max()-PAD,
                     max(L['box'][3] for L in R['legs'])-3))
    hip_y=min(L['hip'][1] for L in near)
    legh=ground-hip_y; s=SQUASH[k]
    drop=(1-s)*legh+DROP[k]
    cx=W/2
    cv=Image.new('RGBA',drum.size,(0,0,0,0))
    def legpart(img,L,out):
        """squash a leg piece down onto the ground and slide it out from the middle"""
        M=np.array([[1.0,0.0],[0.0,s]])
        return place(img,(L['hip'][0] if 'hip' in L else cx,ground),(L.get('hip',(cx,0))[0]+out,ground),M)
    for L in far:
        out=SPLAY[k]*(1 if (L['box'][0]+L['box'][2])/2>cx else -1)*0.6
        cv.alpha_composite(place(L['img'],(cx,ground),(cx+out,ground),np.array([[1.0,0.0],[0.0,s]])))
    # the drum: rocks about its bottom middle and drops onto the flattened legs
    piv=(cx,hip_y)
    t=math.radians(TILT[k])*side
    cv.alpha_composite(place(drum,piv,(cx,hip_y+drop),rot(t)))
    for L in sorted(near,key=lambda L:L['hip'][1]):
        out=SPLAY[k]*(1 if L['hip'][0]>cx else -1)
        for key in ('shin','footimg','ankleimg'):
            cv.alpha_composite(place(L[key],(L['hip'][0],ground),(L['hip'][0]+out,ground),np.array([[1.0,0.0],[0.0,s]])))
        hp=rot(t)@np.array([L['hip'][0]-piv[0],L['hip'][1]-piv[1]])
        cv.alpha_composite(place(L['ball'],(L['hip'][0],L['hip'][1]),(piv[0]+hp[0]+out*0.5,piv[1]+drop+hp[1]),rot(t)))
    # the cannon: knocked off its collar, flies up and lands on its side by the drum
    ga,gl,gs=GUN[k]
    if ga is None: ga=GUN_REST[r]
    gb=np.nonzero(np.array(gun)[...,3]>0); gc=(gb[1].mean()-PAD,gb[0].mean()-PAD)
    g2=place(gun,gc,gc,rot(math.radians(ga)*side)); bb=g2.getbbox()
    if k>=3:      # lying on the ground in front of the drum, to one side
        tx=cx+gs*side; ty=ground+6
        g2=place(g2,(0,0),(tx-((bb[0]+bb[2])/2-PAD),ty-(bb[3]-PAD)),np.eye(2))
    else:
        g2=place(g2,(0,0),(gs*side,drop+gl),np.eye(2))
    cv.alpha_composite(g2)
    if DARK[k]!=1:
        a=np.array(cv).astype(float); a[...,:3]*=DARK[k]; cv=Image.fromarray(a.clip(0,255).astype(np.uint8),'RGBA')
    cell=Image.new('RGB',(CW,CH),tuple(NAVY))
    cell.paste(cv,((CW-cv.width)//2,CH-cv.height+8),cv)
    return cell

if __name__=='__main__':
    sheet=Image.new('RGB',(1536,1024),tuple(NAVY))
    fr={r:[frame(r,k) for k in range(5)] for r in range(5)}
    for r in range(5):
        for k in range(5): sheet.paste(fr[r][k],(k*CW,r*CH))
    sheet.save('art/redraws/netter_death_guide.png')
    g=[]
    for k in range(5):
        o=Image.new('RGB',(5*CW,CH),tuple(NAVY))
        for r in range(5): o.paste(fr[r][k],(r*CW,0))
        g.append(o)
    g[0].save('art/redraws/netter_death_guide.gif',save_all=True,append_images=g[1:],duration=[160,100,110,160,900],loop=0)
    print('ok')
