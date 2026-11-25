import json,collections,datetime as dt,statistics as st,csv
P=lambda s: dt.datetime.fromisoformat(s.replace('Z','+00:00')) if s else None
CAMBIO=P('2026-11-19T18:12:00Z'); NOW=P('2026-11-25T11:45:00Z')
LIMA=dt.timedelta(hours=-5)
runs={};
for l in open('runs_all.jsonl'):
    x=json.loads(l); runs[x['id']]=x
runs=list(runs.values())
prs=json.load(open('prs.json'))
byhead=collections.defaultdict(list)
for r in runs:
    if r['event']=='pull_request': byhead[r['head_branch']].append(r)
rows=[]
for p in prs:
    c=P(p['createdAt'])
    if c<P('2026-10-20T00:00:00Z'): continue
    tl=p['timelineItems']['nodes']
    ame=[P(n['createdAt']) for n in tl if n['__typename']=='AutoMergeEnabledEvent']
    rs=sorted([r for r in byhead[p['headRefName']] if P(r['created_at'])>=c-dt.timedelta(minutes=5) and (not p['closedAt'] or P(r['created_at'])<=P(p['closedAt'])+dt.timedelta(minutes=1))],key=lambda r:r['created_at'])
    dur=[(P(r['updated_at'])-P(r['run_started_at'] or r['created_at'])).total_seconds()/60 for r in rs if r['conclusion']=='success']
    fails=[r for r in rs if r['conclusion']=='failure']
    shas_fail={r['head_sha'] for r in fails}
    succ_after_new=any(r['conclusion']=='success' and r['head_sha'] not in shas_fail and P(r['created_at'])>P(fails[0]['created_at']) for r in rs) if fails else False
    succ_same=any(r['conclusion']=='success' and r['head_sha'] in shas_fail for r in rs) if fails else False
    m=P(p['mergedAt'])
    a=ame[0] if ame else None
    rows.append(dict(numero=p['number'],titulo=p['title'][:90],base=p['baseRefName'],rama=p['headRefName'],
      creado=p['createdAt'],mergeado=p['mergedAt'] or '',cerrado=p['closedAt'] or '',estado=p['state'],
      periodo='despues' if c>=CAMBIO else 'antes',
      auto_merge=a.isoformat() if a else '',
      min_creado_a_merge=round((m-c).total_seconds()/60,1) if m else '',
      min_automerge_a_merge=round((m-a).total_seconds()/60,1) if (m and a) else '',
      runs_ci=len(rs),runs_rojos=len(fails),runs_cancelados=sum(r['conclusion']=='cancelled' for r in rs),
      ci_min_mediana_verde=round(st.median(dur),1) if dur else '',
      solo_docs=bool(dur) and max(dur)<12,
      rojo_arreglado_con_commit=succ_after_new and not succ_same,
      rojo_verde_mismo_commit=succ_same,
      commits=p['commits']['totalCount'],forcepush=sum(n['__typename']=='HeadRefForcePushedEvent' for n in tl)))
with open('prs.csv','w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0].keys()));w.writeheader();w.writerows(rows)
print(len(rows))
