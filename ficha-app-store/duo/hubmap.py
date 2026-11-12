# hubmap.py <captura del Mac> <captura del simulador> → «x0 y0 ancho alto rotación»: dónde se ve la pantalla del simulador
# dentro de Device Hub, en puntos del Mac, y cuántos grados (0/90/180/270, antihorario) la gira Device Hub. Correlación por FFT.
import sys
from PIL import Image
import numpy as np
F=4
macI=Image.open(sys.argv[1]).convert('L'); sim0=Image.open(sys.argv[2]).convert('L')
mac=np.asarray(macI.resize((macI.width//F,macI.height//F)),dtype=np.float64)
H,W=mac.shape
ii=np.pad(mac.cumsum(0).cumsum(1),((1,0),(1,0))); ii2=np.pad((mac**2).cumsum(0).cumsum(1),((1,0),(1,0)))
Fm=np.fft.rfft2(mac)
best=None
for rot in (0,90,180,270):
  sim=sim0.rotate(rot,expand=True)
  for w in range(50,int(W*0.8)):
      h=int(round(sim.height*w/sim.width))
      if h>=H: break
      t=np.asarray(sim.resize((w,h)),dtype=np.float64)
      tp=np.zeros_like(mac); tp[:h,:w]=t
      corr=np.fft.irfft2(Fm*np.conj(np.fft.rfft2(tp)),s=mac.shape)[:H-h+1,:W-w+1]
      S1=ii[h:,w:]-ii[:-h,w:]-ii[h:,:-w]+ii[:-h,:-w]; S2=ii2[h:,w:]-ii2[:-h,w:]-ii2[h:,:-w]+ii2[:-h,:-w]
      S1=S1[:H-h+1,:W-w+1]; S2=S2[:H-h+1,:W-w+1]
      ssd=(S2-2*corr+(t**2).sum())/(w*h)
      i=np.unravel_index(np.argmin(ssd),ssd.shape)
      if best is None or ssd[i]<best[0]: best=(ssd[i],i[1],i[0],w,h,rot)
_,x,y,w,h,rot=best
print(x*F,y*F,w*F,h*F,rot,round(best[0],1))
