from PIL import Image, ImageDraw
import numpy as np, math
S=2.9
gpt=Image.open('wheel_gpt2.png').convert('RGB').crop((0,0,384,512))   # frame-1 painted wheel (rim, depth, bracket)
face=Image.open('wheel_face.png').convert('RGB')
FC=(628,600); FR=470
face=face.crop((FC[0]-FR,FC[1]-FR,FC[0]+FR,FC[1]+FR))     # square around the face
OC=(225,268); ORX,ORY=75,168; HUB=(250,270)
def navy(a): return (a[...,2]>a[...,0]+25)&(a[...,2]>a[...,1]+10)
def wheel_big(angle):
    rot=face.rotate(-angle,resample=Image.BICUBIC,fillcolor=(14,10,12))
    sx,sy=100/FR,196/FR
    sq=rot.resize((int(2*FR*sx*4),int(2*FR*sy*4)),Image.LANCZOS)  # supersample
    sq=sq.resize((int(2*FR*sx),int(2*FR*sy)),Image.LANCZOS)
    out=gpt.copy()
    # opening mask
    m=Image.new('L',out.size,0); ImageDraw.Draw(m).ellipse((OC[0]-ORX,OC[1]-ORY,OC[0]+ORX,OC[1]+ORY),fill=255)
    # protect the hub: hub from the new face is rotation invariant, fine; just paste face centred on HUB
    layer=Image.new('RGB',out.size,(14,10,12))
    layer.paste(sq,(HUB[0]-sq.width//2,HUB[1]-sq.height//2))
    out.paste(layer,(0,0),m)
    return out
def wheel_small(angle):
    b=wheel_big(angle)
    box=(42,51,342,471)
    c=b.crop(box)
    w,h=int(c.width/S),int(c.height/S)
    return c.resize((w,h),Image.LANCZOS)
if __name__=='__main__':
    ims=[wheel_big(7.5*i) for i in range(8)]
    sh=Image.new('RGB',(1536,1024),(0,22,48))
    for i,f in enumerate(ims): sh.paste(f.crop((0,0,384,512)),((i%4)*384,(i//4)*512))
    sh.save('wheel_new_test.png')
