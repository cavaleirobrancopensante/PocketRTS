exec(open('ovl.py').read().split("for pi_,(phi")[0])
import pickle
res=[]
for pi_,(phi,o,d) in enumerate(zip(angles,offs,DISTS)):
    corr=[]
    prev=0.0
    for i in range(48):
        th=math.radians(1.0*i)
        nom=o-th*tower['N']/small['N']
        A=ringmask(ti,th)
        ca=np.zeros((H,W),bool); x0=int(cx0-A.shape[1]/2); y0=int(cy0-A.shape[0]/2); ca[y0:y0+A.shape[0],x0:x0+A.shape[1]]=A
        bx=cx0+d*math.cos(phi); by=cy0+d*math.sin(phi)
        best=(1e9,0)
        for k in range(-24,25):
            c=prev+math.radians(k*0.25)
            B=ringmask(si,nom+c)
            x1=int(bx-B.shape[1]/2); y1=int(by-B.shape[0]/2)
            cb=np.zeros((H,W),bool)
            ys0=max(y1,0); xs0=max(x1,0)
            sub=B[ys0-y1:ys0-y1+min(H-ys0,B.shape[0]-(ys0-y1)), xs0-x1:xs0-x1+min(W-xs0,B.shape[1]-(xs0-x1))]
            cb[ys0:ys0+sub.shape[0],xs0:xs0+sub.shape[1]]=sub
            ov=(ca&cb).sum()+abs(k)*1.5   # prefer small change
            if ov<best[0]: best=(ov,c)
        prev=best[1]; corr.append(prev)
    res.append(corr)
    print(pi_,[round(math.degrees(c),1) for c in corr[::4]])
pickle.dump(res,open('corr.pkl','wb'))
