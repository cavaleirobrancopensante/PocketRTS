from PIL import Image, ImageDraw
import math
im=Image.open('/home/claude/pocketrts/art/redraws/mainspring.png').convert('RGB')
OX,OY=30,100
base=im.crop((OX,OY,OX+340,OY+360))
NAVY=(0,22,48)
def crank(f,d,piv,t,side):
    # side -1 left, +1 right; t angle (0=down)
    L=36
    tx=piv[0]+side*L*0.5*math.sin(t)*1.0
    ty=piv[1]+L*math.cos(t)
    # arm
    vx,vy=tx-piv[0],ty-piv[1]; n=math.hypot(vx,vy); nx,ny=-vy/n*4.6,vx/n*4.6
    poly=[(piv[0]-nx,piv[1]-ny),(tx-nx,ty-ny),(tx+nx,ty+ny),(piv[0]+nx,piv[1]+ny)]
    d.polygon(poly,fill=(184,112,32)); d.line([poly[0],poly[1]],fill=(232,160,56),width=1); d.line([poly[3],poly[2]],fill=(104,56,16),width=1)
    # handle pointing outward
    hx0,hx1=(tx-side*14,tx) if True else (0,0)
    x0,x1=sorted((tx,tx+side*20))
    d.rounded_rectangle((x0,ty-5,x1,ty+5),radius=4,fill=(150,86,60))
    d.line([(x0+1,ty-3),(x1-1,ty-3)],fill=(214,140,100),width=1)
    # elbow cap
    d.ellipse((piv[0]-6,piv[1]-6,piv[0]+6,piv[1]+6),fill=(214,140,40),outline=(90,50,14))
def frame(i):
    f=base.copy(); d=ImageDraw.Draw(f)
    t=2*math.pi*i/8
    # erase cranks (keep shaft stubs)
    d.rectangle((12-0,132,47,212),fill=NAVY)
    d.rectangle((292,132,328,212),fill=NAVY)
    crank(f,d,(41,150),t,-1)
    crank(f,d,(296,150),-t,1)
    # gauge: clear needle, redraw
    gx,gy=200,143
    d.ellipse((gx-14,gy-14,gx+14,gy+14),fill=(226,220,200))
    ang=math.radians(-35+9*math.sin(2*math.pi*i/8))
    for k in range(2):
        d.line([(gx,gy),(gx+14*math.cos(ang+ k*0.0),gy+14*math.sin(ang))],fill=(30,18,14),width=2 if k==0 else 1)
    d.ellipse((gx-2,gy-2,gx+2,gy+2),fill=(120,70,20))
    # spring glint sweep inside the window
    wx,wy,wrx,wry=197,220,43,42
    m=Image.new('L',f.size,0); ImageDraw.Draw(m).ellipse((wx-wrx,wy-wry,wx+wrx,wy+wry),fill=255)
    px=f.load(); bp=m.load()
    pos=-70+ i*20
    for x in range(wx-wrx,wx+wrx+1):
        for y in range(wy-wry,wy+wry+1):
            if bp[x,y]:
                dist=abs((x-wx)*0.8+(y-wy)*0.6-(pos-40))
                if dist<8:
                    a=(8-dist)/8
                    r,g,b=px[x,y]
                    px[x,y]=(min(255,int(r+90*a)),min(255,int(g+100*a)),min(255,int(b+110*a)))
    # steam puff from the vent at the top right, frames 4..7
    if i>=4:
        age=i-4
        for k,(dx,dy,r) in enumerate([(0,0,5),(4,-7,4),(-2,-13,4)]):
            rr=r+age*1.0; yy=243*0+67+dy-age*6
            if age<k*0.7: continue
            g=int(205-age*20)
            d.ellipse((248+dx-rr,yy-rr,248+dx+rr,yy+rr),fill=(g,g,g+6))
    return f
fr=[frame(i) for i in range(8)]
Z=3; W,H=fr[0].size
sheet=Image.new('RGB',(4*(W*Z+40),2*(H*Z+30)),NAVY)
for i,f in enumerate(fr): sheet.paste(f.resize((W*Z,H*Z),Image.NEAREST),((i%4)*(W*Z+40),(i//4)*(H*Z+30)))
sheet.resize((sheet.width//2,sheet.height//2),Image.LANCZOS).save('ms_work_small.png')
fr[0].save('ms_final.gif',save_all=True,append_images=fr[1:],duration=110,loop=0)
