import re,glob,os,json,collections
TS=re.compile(r'^\S+Z ')
runs={str(x['databaseId']):x for x in json.load(open('runs.json'))}
rows=[];per=collections.defaultdict(list);flk=collections.defaultdict(list)
tc=re.compile(r"Test Case '-\[YalaUITests\.(\w+) (\w+)\]' (failed|passed)")
ex=re.compile(r"Test Case '-\[YalaUITests\.(\w+) (\w+)\]' exceeded")
er=re.compile(r"error: -\[YalaUITests\.(\w+) (\w+)\] : (.*)")
for f in sorted(glob.glob('uilogs/*.log')):
    rid,t=os.path.basename(f)[:-4].split('_')
    L=[TS.sub('',l.rstrip('\n')) for l in open(f,errors='ignore')]
    s=next((i for i,l in enumerate(L) if l.startswith('ci-ui-tandas: tanda')),0)
    e=next((i for i,l in enumerate(L) if i>s and 'ci-ui-conteo.sh' in l and '##[group]' in l),len(L))
    reg=L[s:e]
    conteo=next((re.sub(r'^##\[\w+\]','',l) for l in L[e:e+40] if 'ejecutados' in l or 'NO ' in l and 'tanda' in l.lower()),'')
    res=collections.defaultdict(list);errs=collections.defaultdict(list);hung=set()
    for l in reg:
        m=tc.search(l)
        if m: res[f"{m[1]}.{m[2]}"].append(m[3])
        m=ex.search(l)
        if m: hung.add(f"{m[1]}.{m[2]}")
        m=er.search(l)
        if m: errs[f"{m[1]}.{m[2]}"].append(m[3][:200])
    date=runs[rid]['createdAt'][:10]
    red=[k for k,v in res.items() if 'failed' in v and 'passed' not in v]
    red+= [k for k in hung if k not in res]
    fl=[k for k,v in res.items() if 'failed' in v and 'passed' in v]
    for k in red: per[k].append({'run':rid,'fecha':date,'tanda':int(t),'intentos':res.get(k,[]),'cuelgue':k in hung,'errores':list(dict.fromkeys(errs.get(k,[])))[:3]})
    for k in fl: flk[k].append({'run':rid,'fecha':date,'tanda':int(t),'intentos':res[k]})
    rows.append({'run':rid,'fecha':date,'sha':runs[rid]['headSha'][:7],'rama':runs[rid]['headBranch'],'tanda':int(t),'conteo':conteo,'rojas':red,'salvadas_por_reintento':fl})
json.dump({'tandas':rows,'rojas_por_prueba':per,'salvadas_por_reintento':flk},open('ui_agg.json','w'),indent=1,ensure_ascii=False)
print('tandas rojas sin prueba roja identificada:')
for r in rows:
    if not r['rojas']: print(' ',r['run'],r['fecha'],r['tanda'],r['conteo'][:150])
print()
for k,v in sorted(per.items(),key=lambda kv:-len(kv[1])):
    causes=collections.Counter()
    for x in v:
        if x['cuelgue']: causes['cuelgue10min']+=1
        es=' '.join(x['errores'])
        if 'Timed out while evaluating' in es or 'matching snapshots' in es: causes['AX-timeout']+=1
        elif 'XCTAssert' in es: causes['assert']+=1
        elif es: causes['otro']+=1
    print(len(v), k, sorted({x['fecha'][5:] for x in v}), dict(causes), (v[-1]['errores'] or [''])[0][:110])
