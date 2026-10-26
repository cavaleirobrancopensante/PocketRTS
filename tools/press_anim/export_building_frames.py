import numpy as np
from PIL import Image
OUT='/home/claude/pocketrts/art/clockwork/gear/'
def navy(a): return (np.abs(a-np.array([0,22,48])).sum(2)<40)
def to_rgba(img):
    a=np.array(img.convert('RGB')).astype(int); m=~navy(a)
    from scipy import ndimage as ndi
    lab,n=ndi.label(m); 
    if n>1:
        sz=ndi.sum(m,lab,range(1,n+1)); keep=np.isin(lab,[k+1 for k,z in enumerate(sz) if z>=60]); m&=keep
    o=np.zeros(a.shape[:2]+(4,),np.uint8); o[...,:3]=a; o[...,3]=m*255; return Image.fromarray(o,'RGBA')
def cells(path):
    im=Image.open(path).convert('RGB'); W,H=im.size
    return [im.crop((c*W//4,r*H//2,(c+1)*W//4,(r+1)*H//2)) for r in range(2) for c in range(4)]
def save_set(name,static,work):
    frames=[to_rgba(f) for f in static+work]; boxes=[f.getbbox() for f in frames]
    w=max(b[2]-b[0] for b in boxes)+4; h=max(b[3]-b[1] for b in boxes)+4
    for i,(f,b) in enumerate(zip(frames,boxes)):
        c=f.crop(b); o=Image.new('RGBA',(w,h),(0,0,0,0)); o.paste(c,((w-c.width)//2,h-c.height-2))
        tag=['built','construct','damaged','destroyed'][i] if i<4 else 'work_%d'%(i-4)
        o.save(OUT+'%s_%s.png'%(name,tag))
    print(name,w,h,len(work))
g={}; exec(open('/home/claude/pocketrts/tools/press_anim/movement_works_work.py').read().split("fr=[frame(i)")[0],g)
pass #save_set('movement_works',cells('mw_sheet.png')[:4],[g['frame'](i) for i in range(8)])
g={}; import os; os.chdir('/home/claude/pocketrts'); exec(open('tools/press_anim/regulator_work.py').read().split("frames[0].save")[0],g)
save_set('regulator',cells('/home/claude/pocketrts/art/redraws/regulator.png')[:4],g['frames'])
