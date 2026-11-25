import json,glob,re,os,datetime as dt,collections,csv,sys
P=lambda s: dt.datetime.fromisoformat(s.replace('Z','+00:00'))
calls=[]
files=[f for f in glob.glob(os.path.expanduser('~/.claude/projects/*Yala*/*.jsonl'))]
for f in files:
    uses={}
    sess=os.path.basename(os.path.dirname(f)).split('worktrees-')[-1][:70]
    try: lines=open(f,errors='ignore').read().splitlines()
    except: continue
    if 'esperar_merge' not in ''.join(lines[:0]) and not any('esperar_merge' in l for l in lines): continue
    for l in lines:
        try: j=json.loads(l)
        except: continue
        ts=j.get('timestamp'); m=j.get('message') or {}
        if not ts: continue
        c=m.get('content')
        if not isinstance(c,list): continue
        for b in c:
            if b.get('type')=='tool_use' and b.get('name')=='Bash':
                cmd=b['input'].get('command','')
                if 'esperar_merge.py' in cmd and ' estado' not in cmd and '--help' not in cmd:
                    pr=re.search(r'--pr[ =](\d+)|esperar_merge\.py\s+(?:esperar\s+)?(\d+)',cmd)
                    uses[b['id']]=(ts,cmd,pr and (pr.group(1) or pr.group(2)))
            if b.get('type')=='tool_result' and b.get('tool_use_id') in uses:
                t0,cmd,pr=uses.pop(b['tool_use_id'])
                txt=b.get('content'); 
                if isinstance(txt,list): txt=' '.join(x.get('text','') for x in txt if isinstance(x,dict))
                txt=txt or ''
                res=re.findall(r'RESULTADO=([\w-]+)',txt)
                if not pr:
                    m2=re.search(r'PR[ #]*(\d{3,5})',txt); pr=m2 and m2.group(1)
                calls.append(dict(sesion=sess,archivo=os.path.basename(f),pr=pr,inicio=t0,fin=ts,min=round((P(ts)-P(t0)).total_seconds()/60,1),resultado=res[-1] if res else ('error/otro:'+txt[:60].replace('\n',' '))))
calls.sort(key=lambda x:x['inicio'])
with open('esperas_reales.csv','w',newline='') as fh:
    w=csv.DictWriter(fh,fieldnames=list(calls[0].keys()));w.writeheader();w.writerows(calls)
# agrupa por sesion+pr
g=collections.defaultdict(list)
for c in calls: g[(c['sesion'],c['pr'])].append(c)
print('llamadas',len(calls),'esperas (sesion,pr)',len(g))
print(collections.Counter(c['resultado'] for c in calls).most_common(12))
fin=collections.Counter(); tot=[]
for k,v in g.items():
    span=(P(v[-1]['fin'])-P(v[0]['inicio'])).total_seconds()/60
    busy=sum(c['min'] for c in v)
    tot.append((k,v[0]['inicio'][:16],round(span),round(busy),v[-1]['resultado'],len(v)))
    fin[v[-1]['resultado']]+=1
print('resultado final por espera',fin.most_common())
import statistics as st
print('min en espera (suma llamadas) mediana',st.median([t[3] for t in tot]),'media',round(st.mean([t[3] for t in tot]),1),'p90',sorted([t[3] for t in tot])[int(.9*len(tot))])
print('ventana primera->ultima mediana',st.median([t[2] for t in tot]))
for t in tot: print(t)
