"""Pendulum IDLE sway and ATTACK swing in code from ChatGPT's direction sheet (art/redraws/pendulum_dirs.png: 5 rows
S, SE, E, NE, N; column 1 the whole unit, column 2 the pendulum alone, drawn BIGGER than on the body).
1. the separate pendulum is matched to the one on the body at its own scale (multi-scale search, cached in
   pendulum_match.json); 2. the rotating piece = the body's own pixels where they agree with the template, the
   template's pixels where a leg hides it; the hub stays on the body (drawn again on top so the rod comes out from
   under it); 3. holes on the body (where the rod crossed the belly) are filled from neighbouring body pixels, holes
   between the legs stay empty; 4. seen from behind (NE, N) the pendulum is drawn behind the body.
Out: art/redraws/pendulum_idle.png/.gif (5 x 6) and pendulum_attack.png/.gif (5 x 8)."""
import json, math, os, numpy as np
from PIL import Image
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
A=np.array(Image.open('art/redraws/pendulum_dirs.png').convert('RGB')).astype(int)
FULL=[(218,14,422,303),(221,313,416,580),(264,589,363,865),(222,883,416,1156),(222,1179,416,1470)]
PART=[(645,87,738,289),(653,356,736,566),(658,638,714,847),(653,919,719,1133),(645,1230,738,1449)]
BEHIND=[False,False,False,True,True]
MATCH='tools/pendulum_guide/pendulum_match.json'
def crop(box,pad=2):
    x0,y0,x1,y1=box; c=A[y0-pad:y1+pad,x0-pad:x1+pad]; m=np.abs(c-NAVY).sum(2)>45; return c,m
def scaled(P,PM,s):
    w=max(4,int(round(PM.shape[1]*s))); h=max(4,int(round(PM.shape[0]*s)))
    Ps=np.array(Image.fromarray(P.astype(np.uint8)).resize((w,h),Image.LANCZOS)).astype(int)
    Ms=np.array(Image.fromarray((PM*255).astype(np.uint8)).resize((w,h),Image.BILINEAR))>127
    return Ps,Ms
def match(F,FM,P,PM):
    best=(1e18,)
    for s in np.arange(0.50,1.06,0.025):
        Ps,Ms=scaled(P,PM,s); h,w=Ms.shape
        if h>FM.shape[0] or w>FM.shape[1]: continue
        ys,xs=np.nonzero(Ms); pc=Ps[ys,xs]
        for dy in range(0,FM.shape[0]-h+1,3):
            for dx in range(0,FM.shape[1]-w+1,3):
                e=np.abs(F[ys+dy,xs+dx]-pc).sum(1).mean()
                if e<best[0]: best=(e,float(s),dx,dy)
    e,s,dx,dy=best; Ps,Ms=scaled(P,PM,s); h,w=Ms.shape; ys,xs=np.nonzero(Ms); pc=Ps[ys,xs]
    for ddy in range(max(0,dy-3),min(FM.shape[0]-h,dy+3)+1):
        for ddx in range(max(0,dx-3),min(FM.shape[1]-w,dx+3)+1):
            e2=np.abs(F[ys+ddy,xs+ddx]-pc).sum(1).mean()
            if e2<e: e,dx,dy=e2,ddx,ddy
    return s,dx,dy
if os.path.exists(MATCH): M=json.load(open(MATCH))
else:
    M=[]
    for r in range(5):
        F,FM=crop(FULL[r]); P,PM=crop(PART[r]); M.append(match(F,FM,P,PM))
    json.dump(M,open(MATCH,'w'))
def rgba(img,mask):
    o=np.zeros(img.shape[:2]+(4,),np.uint8); o[...,:3]=np.clip(img,0,255); o[...,3]=mask*255; return Image.fromarray(o,'RGBA')
ROWS=[]
for r in range(5):
    F,FM=crop(FULL[r]); P,PM=crop(PART[r]); s,dx,dy=M[r]
    Ps,Ms=scaled(P,PM,s); h,w=Ms.shape; H,W=FM.shape
    T=np.zeros((H,W,3),int); TM=np.zeros((H,W),bool); T[dy:dy+h,dx:dx+w]=Ps; TM[dy:dy+h,dx:dx+w]=Ms
    # the hub: walk up the thin rod from the middle of the template until the outline widens (= the hub's bottom)
    ty,tx=np.nonzero(Ms); top=ty.min()
    rw=lambda y:int(Ms[y].sum())
    mid=top+int(h*0.45)
    rod_w=max(2,min(rw(y) for y in range(top+int(h*0.3),top+int(h*0.55))))
    y=mid
    while y>top and rw(y)<=rod_w*2.2+2: y-=1
    hub_bot=y
    hy,hx=np.nonzero(Ms[top:hub_bot+1])
    hub=(dx+hx.mean(),dy+top+hy.mean()); hub_r=max(5.0,(hub_bot-top)/2.0+1)
    yy,xx=np.mgrid[0:H,0:W]
    hubdisc=np.hypot(xx-hub[0],yy-hub[1])<=hub_r
    agree=TM&FM&(np.abs(F-T).sum(2)<150)
    piece_m=(TM&~hubdisc)
    piece=np.where(agree[...,None],F,T)           # the body's own paint where it shows, the template's where hidden
    # cut EVERYTHING near the template that is not leg paint (red case, blue joints): the painted outline and any
    # bit of the old blade or bob go too, so no ghost is left where the pendulum hung
    R_,G_,B_=F[...,0],F[...,1],F[...,2]
    legpaint=((R_>120)&(G_<95)&(B_<95))|((B_>R_+40)&(B_>110))
    legpaint=ndi.binary_dilation(legpaint,iterations=1)
    near=ndi.binary_dilation(TM,iterations=4)
    below_hub=yy>hub[1]+hub_r*0.6
    cut=near&FM&~hubdisc&((~legpaint&below_hub)|ndi.binary_dilation(agree,iterations=1))
    body=FM&~cut
    # fill a cut pixel when it is surrounded by body (the belly), leave it empty between the legs
    k=np.ones((11,11)); dens=ndi.convolve(body.astype(float),k,mode='constant')/k.sum()
    fill=cut&(dens>0.55)
    _,(iy,ix)=ndi.distance_transform_edt(~body,return_indices=True)
    Fb=F.copy(); Fb[fill]=F[iy[fill],ix[fill]]
    bodym=body|fill
    lab,n=ndi.label(bodym)                       # stray bits of the old pendulum's outline: drop small loose pieces
    if n>1:
        sz=ndi.sum(bodym,lab,range(1,n+1)); bodym&=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=300])
    ROWS.append(dict(body=rgba(Fb,bodym),piece=rgba(piece,piece_m),hub=rgba(F,hubdisc&FM),
                     pivot=hub,size=(W,H)))
CW,CH=204,307
def frame(r,ang,cw=204):
    R=ROWS[r]; W,H=R['size']; pad=140
    def place(img):
        c=Image.new('RGBA',(W+2*pad,H+2*pad),(0,0,0,0)); c.paste(img,(pad,pad)); return c
    piece=place(R['piece']).rotate(ang,resample=Image.NEAREST,center=(R['pivot'][0]+pad,R['pivot'][1]+pad))
    cv=Image.new('RGBA',(W+2*pad,H+2*pad),(0,0,0,0))
    if BEHIND[r]:
        cv.alpha_composite(piece); cv.alpha_composite(place(R['body']))
    else:
        cv.alpha_composite(place(R['body'])); cv.alpha_composite(piece); cv.alpha_composite(place(R['hub']))
    cell=Image.new('RGB',(cw,CH),tuple(NAVY)); x=(cw-cv.width)//2; y=CH-H-8-pad
    cell.paste(cv,(x,y),cv); return cell
def build(seq,name,durs,cw=204):
    sheet=Image.new('RGB',(len(seq)*cw,5*CH),tuple(NAVY))
    for r in range(5):
        for c,a in enumerate(seq): sheet.paste(frame(r,a,cw),(c*cw,r*CH))
    sheet.save('art/redraws/%s.png'%name); g=[]
    for c in range(len(seq)):
        o=Image.new('RGB',(5*cw,CH))
        for r in range(5): o.paste(sheet.crop((c*cw,r*CH,(c+1)*cw,(r+1)*CH)),(r*cw,0))
        g.append(o)
    g[0].save('art/redraws/%s.gif'%name,save_all=True,append_images=g[1:],duration=durs,loop=0)
if __name__=='__main__':
    build([0,4,6,4,0,-4],'pendulum_idle',[170]*6)
    build([0,-14,-34,-48,24,62,40,12],'pendulum_attack',[140,110,110,170,55,90,120,150],cw=330)
    print('ok')
