import math, sys, numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0,'/home/claude/pocketrts/tools/gear_art')
import os; os.chdir('/home/claude/pocketrts')
from rebuild_ring import ring, TOOTH, META
os.chdir('/tmp/claude-0/-home-claude/3bf5c283-94b1-59fe-b83b-7f9d81ecfc35/scratchpad')
NAVY=(0,22,48)
P=33.0
HR=TOOTH.shape[0]/META['tooth']['pitch_px']   # tooth height / pitch
def R_of(n): return n*P/(2*math.pi)
H=P*HR
# nodes: name, kind, n, parent, angle from parent (deg clockwise from top)
NODES=[('tower','tower',38,None,0),
       ('press1','small',21,'tower',55),
       ('ms','small',21,'tower',125),
       ('press2','small',21,'tower',235),
       ('mw1','big',30,'ms',75),
       ('mw2','big',30,'tower',305),
       ('mw3','big',30,'press2',180)]
pos={}; info={}
for name,kind,n,par,ang in NODES:
    if par is None: pos[name]=np.array([0.0,0.0])
    else:
        phi=math.radians(ang); D=R_of(n)+R_of(info[par][1])-H+1.0
        pos[name]=pos[par]+D*np.array([math.sin(phi),-math.cos(phi)])
    info[name]=(kind,n,par,math.radians(ang))
# overlap check
names=[x[0] for x in NODES]
for i,a in enumerate(names):
    for b in names[i+1:]:
        d=np.linalg.norm(pos[a]-pos[b]); lim=R_of(info[a][1])+R_of(info[b][1])-H
        if d<lim-1: print('OVERLAP',a,b,round(d),round(lim))
mins=np.min([pos[k]-R_of(info[k][1]) for k in names],0); maxs=np.max([pos[k]+R_of(info[k][1]) for k in names],0)
print(mins,maxs)
SQ=0.64; DEP=9; TOP=200; PAD=20
W=int(maxs[0]-mins[0]+2*PAD); Hf=int(maxs[1]-mins[1]+2*PAD)
OX=-mins[0]+PAD; OY=-mins[1]+PAD
os.chdir('/home/claude/pocketrts')
IMG={k:ring(info[k][0],info[k][1],int(round(2*R_of(info[k][1])))) for k in names}
os.chdir('/tmp/claude-0/-home-claude/3bf5c283-94b1-59fe-b83b-7f9d81ecfc35/scratchpad')
def angles(t):
    a={'tower':t}
    for name,kind,n,par,ang in NODES[1:]:
        phi=info[name][3]; nA=info[par][1]; aA=a[par]
        a[name]=phi+math.pi+(2*math.pi/n)*((phi-aA)*nA/(2*math.pi)-0.5)
    return a
import numpy as _np
_pl=Image.open('/home/claude/pocketrts/art/clockwork/gear/floor_plate_src.png').convert('RGB')
_a=_np.array(_pl).astype(int); _m=_np.abs(_a-_np.array(NAVY)).sum(2)>40; _ys,_xs=_np.nonzero(_m)
_pl=_pl.crop((_xs.min(),_ys.min(),_xs.max()+1,_ys.max()+1))
_pm=Image.new('L',_pl.size,0); ImageDraw.Draw(_pm).ellipse((0,0,_pl.width-1,_pl.height-1),fill=255)
PLATE=_pl.convert('RGBA'); PLATE.putalpha(_pm)
def hole_r(k):
    kind,n=info[k][0],info[k][1]; R=R_of(n); m=META[kind]
    pitch=2*math.pi*R/n; th=pitch*TOOTH.shape[0]/META['tooth']['pitch_px']; rr=R-th
    return rr*m['r_in']/m['r_root']
def rings(t):
    a=angles(t)
    c=Image.new('RGBA',(W,Hf),NAVY+(255,))
    for k in names:
        d=int(round(2*hole_r(k)+10)); p=PLATE.resize((d,d),Image.LANCZOS)
        c.alpha_composite(p,(int(round(pos[k][0]+OX-d/2)),int(round(pos[k][1]+OY-d/2))))
    for k in names:
        im=IMG[k].rotate(-math.degrees(a[k]),resample=Image.BICUBIC)
        x,y=pos[k][0]+OX,pos[k][1]+OY
        c.alpha_composite(im,(int(round(x-im.width/2)),int(round(y-im.height/2))))
    h2=int(Hf*SQ); c=c.convert('RGB').resize((W,h2),Image.LANCZOS)
    arr=np.array(c).astype(int); m=np.abs(arr-np.array(NAVY)).sum(2)>40
    out=np.zeros((h2+DEP,W,3),int); out[:]=NAVY
    for dd in range(DEP,0,-1):
        sh=np.zeros_like(m); sh[dd:]=m[:-dd]; tt=1-dd/DEP
        col=(np.array([72,46,18])*(0.55+0.45*tt)).astype(int); sel=sh&~m; o=out[:h2]; o[sel]=col
    out[:h2][m]=arr[m]
    full=Image.new('RGB',(W,h2+DEP+TOP),NAVY); full.paste(Image.fromarray(out.astype('uint8')),(0,TOP))
    return full
def cut(img):
    a=np.array(img.convert('RGB')).astype(int); m=np.abs(a-np.array(NAVY)).sum(2)>30
    return img.convert('RGB'), Image.fromarray((m*255).astype('uint8'))
TOWER=cut(Image.open('/home/claude/pocketrts/docs/redraw_refs/clockwork_line/ref_clocktower.png'))
g={}; exec(open('press_new.py').read().split("Z=3")[0],g); PRESS=[cut(f) for f in g['fr']]
g={}; exec(open('ms_v7.py').read().split("Z=3")[0],g); MS=[cut(f) for f in g['fr']]
g={}; exec(open('mw_all7.py').read().split("fr=[frame(i)")[0],g); MW=[cut(g['frame'](i)) for i in range(8)]
def place(canvas,spr,cx,cyg,width):
    img,m=spr; k=width/img.width
    im=img.resize((int(img.width*k),int(img.height*k)),Image.LANCZOS); mm=m.resize(im.size,Image.LANCZOS)
    ys=np.nonzero(np.array(mm)>128)[0]; bottom=ys.max()
    canvas.paste(im,(int(cx-im.width/2),int(cyg-bottom)),mm)
SPR={'tower':('tower',1.25),'press1':('press',1.6),'press2':('press',1.6),'ms':('ms',1.6),'mw1':('mw',1.6),'mw2':('mw',1.6),'mw3':('mw',1.6)}
NF=48; frames=[]
for i in range(NF):
    c=rings(math.radians(1.0*i))
    b=int(i*60/110)%8
    for k in sorted(names,key=lambda k:pos[k][1]):
        R=R_of(info[k][1]); x=pos[k][0]+OX; yg=TOP+(pos[k][1]+OY)*SQ+R*SQ*0.42
        kind,sc=SPR[k]
        spr={'tower':TOWER,'press':PRESS[b],'ms':MS[b],'mw':MW[b]}[kind]
        rr=R*(0.86 if kind!='tower' else 1.0)
        place(c,spr,x,yg,rr*sc*(1.0 if kind!='tower' else 1.0))
    frames.append(c)
a=np.array(frames[0]).astype(int); m=np.abs(a-np.array(NAVY)).sum(2)>40; ys,xs=np.nonzero(m)
box=(max(xs.min()-10,0),max(ys.min()-10,0),xs.max()+10,ys.max()+10)
frames=[f.crop(box) for f in frames]
k=0.8; frames=[f.resize((int(f.width*k),int(f.height*k)),Image.LANCZOS) for f in frames]
frames[0].save('base4_f0.png')
frames[0].save('base4.gif',save_all=True,append_images=frames[1:],duration=60,loop=0)
print(frames[0].size)
