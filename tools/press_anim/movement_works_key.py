from PIL import Image, ImageEnhance
import numpy as np, math
im=Image.open('mw_sheet.png').convert('RGB')
cell=im.crop((0,0,384,512))
a=np.array(cell).astype(int)
nv=(np.abs(a-np.array([0,22,48])).sum(2)<30)
BX0,BY0,BX1,BY1=84,88,200,141
bow=cell.crop((BX0,BY0,BX1,BY1))
bm=Image.fromarray(((~nv[BY0:BY1,BX0:BX1])*255).astype('uint8'))
AX=141   # key axis (shaft centre)
base=cell.copy(); b=np.array(base)
b[BY0:BY1+3,BX0:BX1]=(0,22,48)
# continue the shaft up under the bow
shaft=b[146:151,131:152].copy()
for y in range(126,146,5): b[y:y+5,131:152]=shaft
base=Image.fromarray(b)
frames=[]
N=8
for i in range(N):
    th=math.pi*i/N
    c=math.cos(th); w=max(0.13,abs(c))
    bw=max(3,int(bow.width*w))
    bi=bow.resize((bw,bow.height),Image.LANCZOS); mi=bm.resize((bw,bow.height),Image.LANCZOS)
    if c<0: bi=bi.transpose(Image.FLIP_LEFT_RIGHT); mi=mi.transpose(Image.FLIP_LEFT_RIGHT)
    bi=ImageEnhance.Brightness(bi).enhance(0.78+0.22*abs(c))
    f=base.copy(); f.paste(bi,(int(AX-bw/2),BY0),mi)
    frames.append(f)
frames[0].save('mw_key.gif',save_all=True,append_images=frames[1:],duration=120,loop=0)
strip=Image.new('RGB',(4*200,2*170),(0,22,48))
for i,f in enumerate(frames): strip.paste(f.crop((40,60,240,230)),((i%4)*200,(i//4)*170))
strip.resize((1600,680),Image.NEAREST).save('mw_key_strip.png')
