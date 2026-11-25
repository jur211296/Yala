import json,glob,os,collections,csv
runs={str(x['databaseId']):x for x in json.load(open('runs.json'))}
# nocturnas con tandas ejecutadas
noct=[]
for f in glob.glob('jobs/*.jsonl'):
    rid=os.path.basename(f)[:-6]
    ts=[json.loads(l) for l in open(f)]
    ui=[j for j in ts if j['name'].startswith('UI tests (tanda') and '${{' not in j['name']]
    if ui: noct.append(rid)
noct.sort(key=lambda r:runs[r]['createdAt'])
idx={r:i for i,r in enumerate(noct)}
A=json.load(open('ui_agg.json'))
# rojos por tanda (aviso)
import re
tand={}
for f in glob.glob('aviso/*.log'):
    rid=os.path.basename(f)[:-4]
    if rid not in idx: continue
    t=open(f,errors='ignore').read()
    tand[rid]=dict(re.findall(r'R_UI_(\d+): (\w+)',t))
infra={'42064641786','42247422332','42383702440'}
rows=[]
for k,v in A['rojas_por_prueba'].items():
    ii=sorted({idx[x['run']] for x in v})
    st=1;mx=1
    for a,b in zip(ii,ii[1:]):
        st=st+1 if b==a+1 else 1; mx=max(mx,st)
    last=ii[-1]==len(noct)-1
    cuel=all(x['cuelgue'] for x in v)
    fechas=[runs[noct[i]]['createdAt'][:10] for i in ii]
    # racha final
    streak_end=1
    for a,b in zip(reversed(ii[:-1]),reversed(ii[1:])):
        if b==a+1: streak_end+=1
        else: break
    if cuel: clase='intermitente (cuelgue de 10 min)'
    elif mx>=2 and not (last and streak_end==mx and mx<2): clase='real: rojo varias noches seguidas'
    elif len(ii)>=2: clase='intermitente: rojo y verde sin cambios'
    elif last: clase='nueva el 24-nov: probable real, se confirma esta noche'
    else: clase='intermitente: una sola noche'
    sigue_rojo = last
    err=next((e for x in reversed(v) for e in x['errores']),'(sin mensaje: cuelgue)' if cuel else '')
    rows.append(dict(prueba=k,suite=k.split('.')[0],noches_rojas=len(ii),fechas=' '.join(f[5:] for f in fechas),racha_max=mx,sigue_roja=sigue_rojo,clase=clase,error=err[:160]))
rows.sort(key=lambda r:(-r['noches_rojas'],r['prueba']))
sal=collections.Counter()
for k,v in A['salvadas_por_reintento'].items(): sal[k]=len(v)
with open('pruebas_rojas.csv','w',newline='') as fh:
    w=csv.DictWriter(fh,fieldnames=list(rows[0].keys()));w.writeheader();w.writerows(rows)
# tanda-level
tl=[]
for rid in noct:
    d=tand.get(rid,{})
    reds=[int(k) for k,v in d.items() if v=='failure']
    tl.append(dict(run=rid,fecha=runs[rid]['createdAt'][:10],rama=runs[rid]['headBranch'],sha=runs[rid]['headSha'][:7],evento=runs[rid]['event'],
        tandas=len(d),rojas=len(reds),lista=' '.join(map(str,sorted(reds))),infra=rid in infra))
with open('nocturnas.csv','w',newline='') as fh:
    w=csv.DictWriter(fh,fieldnames=list(tl[0].keys()));w.writeheader();w.writerows(tl)
print('nocturnas',len(noct)); 
for t in tl: print(t['fecha'],t['rama'],t['tandas'],t['rojas'],t['lista'],'INFRA' if t['infra'] else '')
print(collections.Counter(r['clase'] for r in rows))
for r in rows: print(r['noches_rojas'],r['racha_max'],r['clase'][:30],r['prueba'][:85],r['fechas'])
print('salvadas por reintento (top):',sal.most_common(8), 'total casos',sum(sal.values()),'pruebas',len(sal))
