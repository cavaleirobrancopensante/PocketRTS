from PIL import Image, ImageDraw
import numpy as np
g={}; exec(open('press_final_lib.py').read(),g)
import wheel_new as W
base=g['base']
def newwheel(f,angle):
    w=W.wheel_small(angle)
    a=np.array(w).astype(int)
    nv=(a[...,2]>a[...,0]+25)&(a[...,2]>a[...,1]+10)
    m=Image.fromarray(((~nv)*255).astype('uint8'))
    # erase old wheel area slightly inside its silhouette with dark
    d=ImageDraw.Draw(f); d.ellipse((259-45,162-66,259+45,162+66),fill=(14,10,12))
    f.paste(w,(207,89),m)
g['wheel']=newwheel
fr=[g['frame'](i) for i in range(8)]
Z=3;Wd,H=fr[0].size
sheet=Image.new('RGB',(4*(Wd*Z+40),2*(H*Z+30)),(0,22,48))
for i,f in enumerate(fr): sheet.paste(f.resize((Wd*Z,H*Z),Image.NEAREST),((i%4)*(Wd*Z+40),(i//4)*(H*Z+30)))
sheet.resize((sheet.width//2,sheet.height//2),Image.LANCZOS).save('press_new_small.png')
fr[0].save('press_new.gif',save_all=True,append_images=fr[1:],duration=110,loop=0)
