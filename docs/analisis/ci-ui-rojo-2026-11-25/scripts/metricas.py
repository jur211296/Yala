import csv,json,statistics as st,datetime as dt,collections
P=lambda s: dt.datetime.fromisoformat(s.replace('Z','+00:00')) if s else None
CAMBIO=P('2026-11-19T18:12:00Z'); NOW=P('2026-11-25T11:45:00Z')
R=list(csv.DictReader(open('prs.csv')))
W={'antes':(CAMBIO-dt.timedelta(days=14),CAMBIO),'despues':(CAMBIO,NOW)}
def q(v,p):
    v=sorted(v); 
    return round(v[min(len(v)-1,int(p*len(v)))],1) if v else None
M={}
for k,(a,b) in W.items():
    S=[r for r in R if a<=P(r['creado'])<b]
    days=(b-a).total_seconds()/86400
    ame=[r for r in S if r['auto_merge'] and r['mergeado']]
    am=[float(r['min_automerge_a_merge']) for r in ame]
    code=[r for r in ame if r['solo_docs']=='False']
    docs=[r for r in ame if r['solo_docs']=='True']
    amc=[float(r['min_automerge_a_merge']) for r in code]
    cap=[min(x,45) for x in am]
    over=[r for r in ame if float(r['min_automerge_a_merge'])>45]
    red=[r for r in S if int(r['runs_rojos'])>0]
    fixed=[r for r in red if r['rojo_arreglado_con_commit']=='True']
    rer=[r for r in red if r['rojo_verde_mismo_commit']=='True']
    ci=[float(r['ci_min_mediana_verde']) for r in S if r['ci_min_mediana_verde'] and r['solo_docs']=='False']
    M[k]=dict(dias=round(days,2),prs=len(S),prs_dia=round(len(S)/days,1),con_automerge=len(ame),solo_docs=len(docs),
      automerge_a_merge_mediana=q(am,.5),p75=q(am,.75),p90=q(am,.9),
      codigo_mediana=q(amc,.5),codigo_p90=q(amc,.9),
      ci_verde_mediana_codigo=q(ci,.5),
      espera_min_total=round(sum(cap)),espera_min_dia=round(sum(cap)/days),espera_horas_semana=round(sum(cap)/days*7/60,1),
      espera_media_por_pr=round(st.mean(cap),1) if cap else None,
      mas_de_45=len(over), mas_de_3h=sum(float(r['min_automerge_a_merge'])>180 for r in ame),
      no_mergeados=sum(r['estado']!='MERGED' for r in S),
      prs_con_ci_rojo=len(red),rojo_arreglado_con_commit=len(fixed),rojo_verde_al_relanzar=len(rer),
      sin_automerge=sum(1 for r in S if not r['auto_merge']))
    M[k]['lista_rojos']=[(r['numero'],r['titulo'][:60],r['runs_rojos'],r['rojo_arreglado_con_commit'],r['min_automerge_a_merge']) for r in red]
    M[k]['lista_mas_45']=[(r['numero'],r['titulo'][:60],r['min_automerge_a_merge']) for r in over]
json.dump(M,open('metricas.json','w'),indent=1,ensure_ascii=False)
for k,v in M.items():
    print('==',k); [print(' ',a,b) for a,b in v.items() if not a.startswith('lista')]
