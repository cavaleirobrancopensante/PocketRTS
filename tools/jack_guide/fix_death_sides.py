"""ChatGPT's Jack death clean-up landed the body on the wrong side of the spring in rows S and SE (frames 5-7), so the
spring jumped ~54 px sideways. Mirror those three cells and shift them so the spring stays where it stood.
In: the ChatGPT sheet path; out: art/redraws/jack_death_final.png and .gif."""
import sys, numpy as np
from PIL import Image
src=sys.argv[1]
a=np.array(Image.open(src).convert('RGB')).astype(int); H,W=a.shape[:2]; R,C=5,7
NAVY=np.array([0,22,48])
def cell(r,c): return a[r*H//R:(r+1)*H//R, c*W//C:(c+1)*W//C]
def spring_x(sub):
    R_,G,B=sub[...,0],sub[...,1],sub[...,2]
    m=(B>R_+25)&(B>110)&(G>90)&(np.abs(R_-G)<45); xs=np.nonzero(m)[1]; return xs.mean()
out=a.copy()
for r in (0,1):
    tx=spring_x(cell(r,3))
    for c in (4,5,6):
        sub=cell(r,c); f=sub[:,::-1].copy()
        dx=int(round(tx-spring_x(f)))
        g=np.zeros_like(f); g[:]=NAVY
        if dx>=0: g[:,dx:]=f[:,:f.shape[1]-dx]
        else: g[:,:dx]=f[:,-dx:]
        out[r*H//R:(r+1)*H//R, c*W//C:(c+1)*W//C]=g
# then, in every row, keep the spring's foot where it stood: shift the landing frames so the bottom of the coil lines up
from scipy import ndimage as ndi
def foot_x(sub):
    R_,G,B=sub[...,0],sub[...,1],sub[...,2]
    m=(B>R_+25)&(B>110)&(G>90)&(np.abs(R_-G)<45)
    lab,n=ndi.label(ndi.binary_dilation(m,iterations=2)); sz=ndi.sum(m,lab,range(1,n+1)); k=int(np.argmax(sz))+1
    ys,xs=np.nonzero((lab==k)&m); return xs[ys>=ys.max()-6].mean()
for r in range(R):
    sl=lambda c:(slice(r*H//R,(r+1)*H//R),slice(c*W//C,(c+1)*W//C))
    tx=foot_x(out[sl(3)])
    for c in (4,5,6):
        f=out[sl(c)].copy(); dx=int(round(tx-foot_x(f)))
        fg=np.abs(f-NAVY).sum(2)>45; xs=np.nonzero(fg)[1]
        dx=max(min(dx,f.shape[1]-1-xs.max()),-xs.min())      # never push the figure out of its cell
        g=np.zeros_like(f); g[:]=NAVY
        if dx>=0: g[:,dx:]=f[:,:f.shape[1]-dx]
        else: g[:,:dx]=f[:,-dx:]
        out[sl(c)]=g
img=Image.fromarray(out.astype(np.uint8)); img.save('art/redraws/jack_death_final.png')
cw=W//C; ch=H//R; fr=[]
for c in range(C):
    o=Image.new('RGB',(5*cw,ch))
    for r in range(R): o.paste(img.crop((c*W//C,r*H//R,c*W//C+cw,r*H//R+ch)),(r*cw,0))
    fr.append(o)
fr[0].save('art/redraws/jack_death_final.gif',save_all=True,append_images=fr[1:],duration=[150,80,90,90,110,110,900],loop=0)
print('ok')
