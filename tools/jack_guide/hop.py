"""Jack HOP (its walk: small pogo hops; generated from jump.py with a smaller sequence). Jack JUMP built in code from the painted idle frame: the coil spring between the body and the foot plate is
squashed (crouch) or stretched (launch) column-wise, the body and arms ride on top, and in the air the whole unit
lifts with a ground shadow left behind. Out: art/redraws/jack_hop.png (5 rows x 8 frames) and .gif. Pose guide."""
import numpy as np
from PIL import Image, ImageDraw
NAVY=np.array([0,22,48])
im=np.array(Image.open('art/redraws/jack_idle.png').convert('RGB')).astype(int)
BOX=[(159,23,306,181),(174,216,299,360),(170,387,301,537),(166,571,308,713),(164,743,308,873)]
# per row: spring top y, foot-plate top y, spring x range (crop coords)
SPR=[(86,133,52,104),(84,122,40,88),(97,128,42,92),(82,120,43,92),(78,110,43,88)]
# per frame: spring height factor, lift (px)
SEQ=[(1.0,0),(0.72,0),(1.25,7),(1.12,14),(1.0,8),(0.78,0)]
PAD=120
def frame(r,k,l):
    x0,y0,x1,y1=BOX[r]; F=im[y0:y1,x0:x1]; M=np.abs(F-NAVY).sum(2)>45
    st,bt,sx0,sx1=SPR[r]; h,w=M.shape; L=bt-st; nL=max(3,int(round(L*k)))
    out=np.zeros((h+2*PAD,w+2*PAD,3),int); out[:]=NAVY; om=np.zeros(out.shape[:2],bool)
    gy=PAD+h   # ground under the plate stays at the same row when not lifted
    def put(src_rows,src_cols,dst_y0,mask_fn=None):
        pass
    dy=nL-L   # body moves by this (negative = down when squashed)
    # shadow on the ground when in the air
    if l>0:
        sh=Image.new('L',(out.shape[1],out.shape[0]),0); d=ImageDraw.Draw(sh)
        cx=PAD+(sx0+sx1)/2; cy=PAD+h-6; rx=(sx1-sx0)*0.7*(1-l/120); ry=rx*0.35
        d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill=255); s=np.array(sh)>0
        out[s]=(out[s]*0.35+np.array([0,8,20])*0.65).astype(int)
    lift=-l
    # foot plate (below bt): unchanged, lifted in the air
    ys=np.arange(bt,h)
    for y in ys:
        row=M[y]; ty=PAD+y+lift; out[ty,PAD:PAD+w][row]=F[y][row]; om[ty,PAD:PAD+w]|=row
    # spring band, columns sx0..sx1, rows st..bt resampled to nL rows ending at bt
    for t in range(nL):
        sy=st+int(t*L/nL); ty=PAD+bt-nL+t+lift
        row=M[sy,sx0:sx1]; out[ty,PAD+sx0:PAD+sx1][row]=F[sy,sx0:sx1][row]
    # body: rows < st, plus band pixels outside the spring columns; shifted so its bottom meets the spring top
    shift=-(nL-L)+lift
    for y in range(0,bt):
        row=M[y].copy()
        if y>=st: row[sx0:sx1]=False
        ty=PAD+y+shift
        if 0<=ty<out.shape[0]: out[ty,PAD:PAD+w][row]=F[y][row]
    return Image.fromarray(out.astype(np.uint8))
if __name__=='__main__':
    CW,CH=1536//6,1024//5
    sheet=Image.new('RGB',(1536,1024),tuple(NAVY))
    for r in range(5):
        for c,(k,l) in enumerate(SEQ):
            f=frame(r,k,l); bb=f.getbbox()
            f=f.crop((PAD//2,PAD//2,f.width-PAD//2,f.height-PAD//2)) if False else f
            # fit cell: centre on the plate, bottom of the cell = ground
            x0,y0,x1,y1=BOX[r]; w=x1-x0; h=y1-y0
            cx=PAD+w//2; gy=PAD+h
            cell=f.crop((cx-CW//2,gy-CH+8,cx+CW//2,gy+8))
            sheet.paste(cell,(c*CW,r*CH))
    sheet.save('art/redraws/jack_hop.png')
    g=[]
    for c in range(6):
        o=Image.new('RGB',(5*CW,CH))
        for r in range(5): o.paste(sheet.crop((c*CW,r*CH,(c+1)*CW,(r+1)*CH)),(r*CW,0))
        g.append(o)
    g[0].save('art/redraws/jack_hop.gif',save_all=True,append_images=g[1:],duration=[90,80,70,80,80,90],loop=0)
    print('ok')
