# mappt.py <captura del simulador> "<x0 y0 ancho alto rotación>" <x> <y> [<x2> <y2>]: puntos de la app → puntos del Mac.
import sys
from PIL import Image
args=[sys.argv[0],sys.argv[1]]+' '.join(sys.argv[2:]).split()
sys.argv=args
im=Image.open(sys.argv[1]); AW,AH=im.width/3,im.height/3
X0,Y0,W,H=map(float,sys.argv[2:6]); rot=int(sys.argv[6]); pts=list(map(float,sys.argv[7:]))
out=[]
for i in range(0,len(pts),2):
    px,py=pts[i],pts[i+1]
    if rot==0: nx,ny,nw=px,py,AW
    elif rot==90: nx,ny,nw=py,AW-px,AH
    elif rot==180: nx,ny,nw=AW-px,AH-py,AW
    else: nx,ny,nw=AH-py,px,AH
    k=W/nw; out+= [round(X0+nx*k,1), round(Y0+ny*k,1)]
print(*out)
