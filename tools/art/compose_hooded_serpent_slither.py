# Builds art/redraws/hooded_serpent_slither_se_composed.png: the coiling slither (hooded_serpent_slither_coil_chatgpt.png) with the tail fan from the other try (hooded_serpent_slither_fan_chatgpt.png) grafted on each frame's tail.
#   python3 tools/art/compose_hooded_serpent_slither.py [fan_rows 110] [join 30] [out]
import sys
from PIL import Image
import numpy as np
from scipy import ndimage
R='art/redraws/'
def comps(f):
    im=np.array(Image.open(R+f).convert('RGB')).astype(float)
    bg=im[5,5]; d=np.sqrt(((im-bg)**2).sum(-1)); m=ndimage.binary_closing(d>40,iterations=2)
    lab,n=ndimage.label(m); out=[]
    for i,s in enumerate(ndimage.find_objects(lab)):
        if (lab[s]==i+1).sum()>3000:
            mk=(lab==i+1)
            mk=ndimage.binary_dilation(mk,iterations=2)
            out.append((s[1].start,s,mk))
    out.sort(key=lambda t:t[0])
    return im,bg,out
fim,fbg,fc=comps('hooded_serpent_slither_fan_chatgpt.png')
cim,cbg,cc=comps('hooded_serpent_slither_coil_chatgpt.png')
FAN_H=int(sys.argv[1]) if len(sys.argv)>1 else 110
JOIN=int(sys.argv[2]) if len(sys.argv)>2 else 30
W,H=600,600
sheet=Image.new('RGB',(W*6,H),tuple(int(v) for v in cbg))
for i in range(6):
    # the fan: the fan frame's top FAN_H rows of its own component
    _,s,mk=fc[i]; y0=s[0].start
    fan=np.zeros((FAN_H,fim.shape[1],4),np.uint8)
    reg=mk[y0:y0+FAN_H]
    sl,sn=ndimage.label(reg)
    if sn>1:
        sizes=ndimage.sum(reg,sl,range(1,sn+1)); reg=(sl==(int(np.argmax(sizes))+1))
    fan[...,:3]=fim[y0:y0+FAN_H].astype(np.uint8); fan[...,3]=reg*255
    ys,xs=np.nonzero(reg[-JOIN:]); fx=int(np.median(xs))   # where the fan's stalk leaves it (bottom rows)
    # (only the fan itself: nothing far to the right of the stalk, where the body's own spikes start)
    reg=reg.copy(); reg[:, fx+45:]=False
    fan[...,3]=reg*255
    xa,xb=xs.min(),xs.max()
    fanimg=Image.fromarray(fan,'RGBA').crop((max(0,fx-200),0,fx+200,FAN_H))
    # the coil frame, its tail tip: the body's top JOIN rows
    _,t,cm=cc[i]; ty=t[0].start
    frame=np.zeros(cim.shape[:2]+(4,),np.uint8); frame[...,:3]=cim.astype(np.uint8); frame[...,3]=cm*255
    tip=cm[ty+JOIN:ty+JOIN+12]; tys,txs=np.nonzero(tip); tx=int(np.median(txs))
    frame[:ty+JOIN, :, 3]=np.where(np.abs(np.arange(frame.shape[1])-tx)<60, 0, frame[:ty+JOIN,:,3])   # cut the plain spike
    x0,x1=t[1].start,t[1].stop
    fr=Image.fromarray(frame,'RGBA').crop((x0-60,ty-FAN_H,x1+20,t[0].stop+5))
    out=Image.new('RGBA',(W,H),(0,0,0,0))
    ox=(W-fr.width)//2+60; out.alpha_composite(fr,(ox,H-fr.height))
    # place the fan so its stalk meets the cut tail
    px=ox+(tx-(x0-60))-200; py=H-fr.height+FAN_H+JOIN-FAN_H+6
    out.alpha_composite(fanimg,(px,py))
    sheet.paste(out,(i*W,0),out)
sheet.save(sys.argv[3] if len(sys.argv)>3 else R+'hooded_serpent_slither_se_composed.png')
