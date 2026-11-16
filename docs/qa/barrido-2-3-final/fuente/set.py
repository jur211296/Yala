#!/usr/bin/env python3
"""Fija el resultado de una card: set.py <sid> <destino> <donde> <que> [--motivo ..] [--ev a.jpg,b.mp4] [--paso ..]...
destino: done · backlog · jurgen-prueba · jurgen-visto · espera"""
import json,sys,argparse,pathlib
p=argparse.ArgumentParser();p.add_argument('sid');p.add_argument('destino');p.add_argument('donde');p.add_argument('que')
p.add_argument('--motivo',default='');p.add_argument('--ev',default='');p.add_argument('--paso',action='append',default=[])
a=p.parse_args()
f=pathlib.Path(__file__).with_name('resultados.json');r=json.loads(f.read_text())
for c in r:
    if c['sid']==a.sid:
        c.update(destino=a.destino,donde=a.donde,que=a.que,motivo=a.motivo,evidencia=[x for x in a.ev.split(',') if x],pasos=a.paso);break
else: sys.exit('no existe '+a.sid)
f.write_text(json.dumps(r,ensure_ascii=False,indent=1));print('ok',a.sid,a.destino)
