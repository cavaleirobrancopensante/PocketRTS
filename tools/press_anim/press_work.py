from PIL import Image, ImageDraw
import math, random
im=Image.open('/home/claude/pocketrts/art/redraws/cog_press.png').convert('RGB')
base=im.crop((30,80,360,460))
HX,HY=280,169; OX,OY,ORX,ORY=271,166,26,55
def wheel(f,angle):
    mask=Image.new('L',f.size,0)
    ImageDraw.Draw(mask).ellipse((OX-ORX,OY-ORY,OX+ORX,OY+ORY),fill=255)
    layer=Image.new('RGB',f.size,(14,10,12)); d=ImageDraw.Draw(layer)
    def ray(th,L,w,col,hi,lo,taper=1.0):
        ex,ey=HX+L*math.cos(th)*0.55,HY+L*math.sin(th)
        px,py=-math.sin(th)*0.55,math.cos(th); n=math.hypot(px,py)
        ox,oy=px/n*w,py/n*w
        poly=[(HX-ox,HY-oy),(ex-ox*taper,ey-oy*taper),(ex+ox*taper,ey+oy*taper),(HX+ox,HY+oy)]
        d.polygon(poly,fill=col)
        d.line([poly[0],poly[1]],fill=hi,width=1); d.line([poly[3],poly[2]],fill=lo,width=1)
    for i in range(6):   # dark shafts behind, between spokes
        ray(math.radians(angle+30+60*i),62,5.5,(52,50,58),(96,94,104),(26,24,30),0.7)
    for i in range(6):
        ray(math.radians(angle+60*i),62,4.2,(176,108,30),(228,156,52),(96,50,14),1.25)
    hm=Image.new('L',f.size,0); ImageDraw.Draw(hm).ellipse((HX-12,HY-15,HX+12,HY+15),fill=255)
    layer.paste(base,(0,0),hm)
    f.paste(layer,(0,0),mask)
cogsrc=base.crop((158,356,178,376))   # small loose cog
cm=Image.new('L',cogsrc.size,0)
px=cogsrc.load()
for x in range(cogsrc.width):
    for y in range(cogsrc.height):
        r,g,b=px[x,y]
        if r>90 and r>b+40: cm.putpixel((x,y),255)
def puff(f,x,y,age):
    d=ImageDraw.Draw(f)
    for k,(dx,dy,r) in enumerate([(0,0,5),(5,-6,4),(-3,-12,5),(4,-17,3)]):
        if age<k*0.5: continue
        yy=y+dy-age*6; rr=r+age*1.2
        if rr>9: continue
        g=int(200-age*18)
        d.ellipse((x+dx-rr,yy-rr,x+dx+rr,yy+rr),fill=(g,g,g+6))
PIST=[0,3,8,13,13,8,4,1]
def frame(i):
    f=base.copy()
    drop=PIST[i]
    if drop:
        x0,x1,y0,y1=112,162,132,235
        blk=base.crop((x0,y0,x1,y1))
        f.paste(base.crop((x0,y0,x1,y0+1)).resize((x1-x0,drop),Image.NEAREST),(x0,y0))
        f.paste(blk,(x0,y0+drop))
    wheel(f,7.5*i)
    # falling cog after the slam (frames 4-7)
    if 4<=i<=7:
        t=(i-4)/3; cx=int(120-4*t); cy=int(236+38*t)
        f.paste(cogsrc,(cx,cy),cm)
    if i>=3 and i<=7: puff(f,205,66,i-3)
    if i==3:
        g=Image.new('RGB',f.size,(0,22,48)); g.paste(f,(0,1)); f=g
    return f
fr=[frame(i) for i in range(8)]
Z=3; W,H=fr[0].size
sheet=Image.new('RGB',(4*(W*Z+40),2*(H*Z+30)),(0,22,48))
for i,f in enumerate(fr):
    sheet.paste(f.resize((W*Z,H*Z),Image.NEAREST),((i%4)*(W*Z+40),(i//4)*(H*Z+30)))
sheet.save('press_work_sheet.png')
sheet.resize((sheet.width//2,sheet.height//2),Image.LANCZOS).save('press_work_small.png')
fr[0].save('press_final.gif',save_all=True,append_images=fr[1:],duration=110,loop=0)
print(sheet.size)
