import csv,collections,datetime as dt,statistics as st,json
P=lambda s: dt.datetime.fromisoformat(s.replace('Z','+00:00')) if s else None
OK={'sigue','tope','mergeado','conflicto','ci-rojo','sin-cola','cerrado'}
rows=[]
for m,f in [('Max','esperas_max.csv'),('Mini','esperas_mini.csv')]:
    for r in csv.DictReader(open(f)):
        if r['pr'] and r['resultado'] in OK and len(r['pr'])>=3: r['maquina']=m; rows.append(r)
prs={r['numero']:r for r in csv.DictReader(open('prs.csv'))}
g=collections.defaultdict(list)
for r in rows: g[(r['maquina'],r['sesion'],r['pr'])].append(r)
E=[]
for (m,s,pr),v in g.items():
    v.sort(key=lambda r:r['inicio'])
    p=prs.get(pr,{})
    E.append(dict(maquina=m,sesion=s,pr=pr,inicio=v[0]['inicio'],fin=v[-1]['fin'],
        min_esperando=round(sum(float(x['min']) for x in v),1),
        min_ventana=round((P(v[-1]['fin'])-P(v[0]['inicio'])).total_seconds()/60,1),
        llamadas=len(v),resultado_final=v[-1]['resultado'],
        vio_conflicto=any(x['resultado']=='conflicto' for x in v),vio_ci_rojo=any(x['resultado']=='ci-rojo' for x in v),
        solo_docs=p.get('solo_docs',''),mergeado_pr=p.get('mergeado',''),
        min_tras_fin_hasta_merge=round((P(p['mergeado'])-P(v[-1]['fin'])).total_seconds()/60,1) if p.get('mergeado') else ''))
E.sort(key=lambda e:e['inicio'])
with open('esperas_por_sesion.csv','w',newline='') as fh:
    w=csv.DictWriter(fh,fieldnames=list(E[0].keys()));w.writeheader();w.writerows(E)
print('esperas',len(E),collections.Counter(e['maquina'] for e in E))
print('primera',E[0]['inicio'],'ultima',E[-1]['inicio'])
for cat in ['True','False']:
    S=[e for e in E if e['solo_docs']==cat]
    print('solo_docs' if cat=='True' else 'codigo',len(S),collections.Counter(e['resultado_final'] for e in S).most_common(),
      'min med',st.median([e['min_esperando'] for e in S]) if S else '', 'suma',round(sum(e['min_esperando'] for e in S)))
    tr=[e['min_tras_fin_hasta_merge'] for e in S if e['resultado_final']=='tope' and e['min_tras_fin_hasta_merge']!='']
    if tr: print('   tras el tope, minutos hasta el merge: mediana',st.median(tr),'p90',sorted(tr)[int(.9*len(tr))])
unk=[e for e in E if e['solo_docs']=='']
print('sin clasificar',len(unk),[e['pr'] for e in unk])
print('conflicto visto',sum(e['vio_conflicto'] for e in E),'ci-rojo visto',sum(e['vio_ci_rojo'] for e in E))
a=P(E[0]['inicio']);b=P('2026-11-25T11:45:00Z');days=(b-a).total_seconds()/86400
tot=sum(e['min_esperando'] for e in E)
print('dias',round(days,2),'min total',round(tot),'min/dia',round(tot/days),'h/semana',round(tot/days*7/60,1))
byday=collections.Counter()
for e in E: byday[(P(e['inicio'])-dt.timedelta(hours=5)).date().isoformat()]+=e['min_esperando']
print(sorted((k,round(v)) for k,v in byday.items()))
json.dump(sorted((k,round(v)) for k,v in byday.items()),open('espera_por_dia.json','w'))
