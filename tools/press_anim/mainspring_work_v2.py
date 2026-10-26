from PIL import Image
import numpy as np, math
src=open('ms_final.py').read().split("fr=[frame(i)")[0]
g={}; exec(src,g)
S=0.09
cr=Image.open('crank2.png').convert('RGB')
a=np.array(cr).astype(int); nvm=(a[...,2]>a[...,0]+25)&(a[...,2]>a[...,1]+10)
def part(box):
    c=cr.crop(box); m=Image.fromarray(((~nvm[box[1]:box[3],box[0]:box[2]])*255).astype('uint8'))
    return c,m
hub,hubm=part((540,157,905,385)); arm,armm=part((640,385,780,1020)); han,hanm=part((224,890,655,1056))
def sc(img,k,mode=Image.LANCZOS): return img.resize((max(1,int(img.width*k)),max(1,int(img.height*k))),mode)
def paste(f,img,m,x,y,flipy=False,h=None):
    if h is not None: img=img.resize((img.width,max(2,int(h))),Image.LANCZOS); m=m.resize(img.size,Image.LANCZOS)
    if flipy: img=img.transpose(Image.FLIP_TOP_BOTTOM); m=m.transpose(Image.FLIP_TOP_BOTTOM)
    f.paste(img,(int(x),int(y)),m)
def crank(f,d,piv,t,side):
    layer=Image.new('RGB',(160,160),(0,22,48)); lm=Image.new('L',(160,160),0)
    P=(80,80)                      # pivot in layer
    cosT=math.cos(t); sinT=math.sin(t)
    armfull=635*S
    # hub centre in hub crop = (715-540,275-157)
    hw,hh=sc(hub,S),None
    armS=sc(arm,S); armmS=sc(armm,S)
    handS=sc(han,S); handmS=sc(hanm,S)
    # arm: starts at pivot, visible length = cos*(700*S)
    reach=700*S*cosT
    vis=max(abs(reach),4)
    ax=P[0]-armS.width/2+ 0.25*700*S*sinT*(-1)*0   # no sway
    if reach>=0:
        paste_layers=[]
        top=P[1]
        ai=armS.resize((armS.width,int(vis)),Image.LANCZOS); am=armmS.resize(ai.size,Image.LANCZOS)
        layer.paste(ai,(int(ax),int(top)),am); lm.paste(am,(int(ax),int(top)),am)
        tipy=P[1]+reach
    else:
        ai=armS.resize((armS.width,int(vis)),Image.LANCZOS).transpose(Image.FLIP_TOP_BOTTOM); am=armmS.resize(ai.size,Image.LANCZOS).transpose(Image.FLIP_TOP_BOTTOM)
        top=P[1]-vis
        layer.paste(ai,(int(ax),int(top)),am); lm.paste(am,(int(ax),int(top)),am)
        tipy=P[1]+reach
    # handle: right end near arm centre
    hx=P[0]+(655-715)*S-handS.width+ (handS.width) - (655-224)*S
    hy=tipy-(975-890)*S
    layer.paste(handS,(int(hx),int(hy)),handmS); lm.paste(handmS,(int(hx),int(hy)),handmS)
    # hub on top
    hx0=P[0]-(715-540)*S; hy0=P[1]-(275-157)*S
    hs=sc(hub,S); hm=sc(hubm,S)
    layer.paste(hs,(int(hx0),int(hy0)),hm); lm.paste(hm,(int(hx0),int(hy0)),hm)
    if side>0:
        layer=layer.transpose(Image.FLIP_LEFT_RIGHT); lm=lm.transpose(Image.FLIP_LEFT_RIGHT)
    f.paste(layer,(int(piv[0]-80),int(piv[1]-80)),lm)
g['crank']=crank
# frame() in g calls crank(f,d,..) with global name -> overridden
fr=[g['frame'](i) for i in range(8)]
Z=3; W,H=fr[0].size
sh=Image.new('RGB',(4*(W*Z+40),2*(H*Z+30)),(0,22,48))
for i,f in enumerate(fr): sh.paste(f.resize((W*Z,H*Z),Image.NEAREST),((i%4)*(W*Z+40),(i//4)*(H*Z+30)))
sh.resize((sh.width//2,sh.height//2),Image.LANCZOS).save('ms_v2_small.png')
fr[0].save('ms_v2.gif',save_all=True,append_images=fr[1:],duration=110,loop=0)
