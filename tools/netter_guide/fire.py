"""Netter FIRE (recoil) in code from ChatGPT's direction sheet (art/redraws/netter_dirs.png: 5 rows S, SE, E, NE, N;
column 1 the whole unit, column 2 the cannon alone, drawn at its own scale). The cannon is matched on the body at its
own scale, cut out (the collar stays), and kicked back along its barrel and eased home while the drum dips; the net and
the puff of steam are game effects. Also cuts the flying net and the spread net out of the chosen concept
(art/redraws/concepts/netter_v2.png). Out: art/redraws/netter_fire.png/.gif (5 x 6), netter_net_fly.png, netter_net_open.png."""
import json, os, numpy as np
from PIL import Image
from scipy import ndimage as ndi
NAVY=np.array([0,22,48])
A=np.array(Image.open('art/redraws/netter_dirs.png').convert('RGB')).astype(int)
FULL=[(302,21,562,213),(324,224,561,394),(303,409,575,565),(307,579,544,767),(314,780,547,963)]
PART=[(988,73,1083,200),(987,268,1126,378),(964,443,1148,546),(994,601,1121,744),(992,818,1075,961)]
KICK=[(0,-4),(-4,-1),(-5,0),(-4,2),(0,4)]     # screen direction of the recoil (opposite to the barrel)
def crop(box,pad=2):
    x0,y0,x1,y1=box; c=A[y0-pad:y1+pad,x0-pad:x1+pad]; m=np.abs(c-NAVY).sum(2)>45; return c,m
# ChatGPT's separate cannons are redrawn, not copies (template matching fails), so the cannon is cut off the body along
# a hand-set line just above the drum: per row a default height and (x0, x1, y) spans where the gun reaches lower.
CUT=[(57,[]),(43,[(168,216,50)]),(41,[(165,276,44)]),(51,[(110,161,56)]),(54,[])]
def rgba(img,mask):
    o=np.zeros(img.shape[:2]+(4,),np.uint8); o[...,:3]=np.clip(img,0,255); o[...,3]=mask*255; return Image.fromarray(o,'RGBA')
ROWS=[]
for r in range(5):
    F,FM=crop(FULL[r]); H,W=FM.shape
    lim=np.full(W,CUT[r][0])
    for x0,x1,y in CUT[r][1]: lim[x0:x1]=y
    yy,xx=np.mgrid[0:H,0:W]
    gun=FM&(yy<lim[None,:])
    ROWS.append(dict(body=rgba(F,FM&~gun),gun=rgba(F,gun),size=(W,H)))
CW,CH=307,204
SEQ=[(0,0),(1.0,1),(0.7,1),(0.4,0),(0.15,0),(0,0)]     # (kick share, drum dip px)
sheet=Image.new('RGB',(len(SEQ)*CW,5*CH),tuple(NAVY))
for r in range(5):
    R=ROWS[r]; W,H=R['size']
    for c,(k,dip) in enumerate(SEQ):
        cv=Image.new('RGBA',(W+40,H+40),(0,0,0,0))
        cv.alpha_composite(R['body'],(20,20+dip))
        kx,ky=KICK[r]; n=max(abs(int(round(kx*k))),abs(int(round(ky*k))),1)
        for i in range(n+1):        # stacked: the gun slides back over its own trail (no gap at the collar)
            t=i/n; cv.alpha_composite(R['gun'],(20+int(round(kx*k*t)),20+int(round(ky*k*t))+dip))
        cell=Image.new('RGB',(CW,CH),tuple(NAVY)); cell.paste(cv,((CW-cv.width)//2,CH-cv.height+8),cv)
        sheet.paste(cell,(c*CW,r*CH))
sheet.save('art/redraws/netter_fire.png'); g=[]
for c in range(len(SEQ)):
    o=Image.new('RGB',(5*CW,CH))
    for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
    g.append(o)
g[0].save('art/redraws/netter_fire.gif',save_all=True,append_images=g[1:],duration=[300,60,80,90,100,300],loop=0)
# the nets from the concept
C=np.array(Image.open('art/redraws/concepts/netter_v2.png').convert('RGB')).astype(int)
def cut_obj(x0,y0,x1,y1,name):
    sub=C[y0:y1,x0:x1]; m=np.abs(sub-NAVY).sum(2)>45
    grey=(np.abs(sub[...,0]-sub[...,1])<30)&(np.abs(sub[...,1]-sub[...,2])<40)&(sub.sum(2)>200)
    m&=~grey if name=='netter_net_fly' and False else m
    lab,n=ndi.label(ndi.binary_closing(m,iterations=2)); sz=ndi.sum(m,lab,range(1,n+1)); keep=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>=40])
    img=rgba(sub,m&keep); img=img.crop(img.getbbox()); img.save('art/redraws/%s.png'%name)
cut_obj(890,355,1050,470,'netter_net_fly')
cut_obj(1075,300,1510,660,'netter_net_open')
print('ok')
