import sys,xml.etree.ElementTree as ET
from collections import Counter
hangs_xml, tp_xml = sys.argv[1], sys.argv[2]
root=ET.parse(hangs_xml).getroot(); ids={}; hangs=[]
for row in root.iter('row'):
    v={}
    for el in row:
        node=ids.get(el.get('ref'),el)
        if el.get('id'): ids[el.get('id')]=el
        v[el.tag]=node.text
    hangs.append((int(v['start-time']), int(v['duration'])))
owners=[Counter() for _ in hangs]
frames={}; bts={}; ids={}
def dueno(names):
    j=' '.join(names)
    if 'PanelViewModel.performCalculationInStages' in j or 'PanelViewModel.finishRecalculation' in j: return 'Panel'
    if 'WidgetDataCache' in j: return 'Widgets'
    if 'Spotlight' in j: return 'Spotlight'
    return 'Otro'
for ev,row in ET.iterparse(tp_xml):
    if row.tag!='row': continue
    t=None; th=None; names=None
    for el in row:
        if el.tag=='sample-time':
            node=ids.get(el.get('ref'),el)
            if el.get('id'): ids[el.get('id')]=el
            t=int(node.text)
        elif el.tag=='thread':
            node=ids.get(el.get('ref'),el)
            if el.get('id'): ids[el.get('id')]=el
            th=node.get('fmt') or ''
        elif el.tag in('backtrace','tagged-backtrace'):
            if el.get('ref'): names=bts.get(el.get('ref'),[])
            else:
                names=[]
                for f in el.iter('frame'):
                    if f.get('ref'): names.append(frames.get(f.get('ref'),'?'))
                    else: frames[f.get('id')]=f.get('name') or '?'; names.append(frames[f.get('id')])
                bts[el.get('id')]=names
    if t is not None and th and 'Main Thread' in th and names is not None:
        for i,(s,d) in enumerate(hangs):
            if s<=t<=s+d: owners[i][dueno(names)]+=1
    row.clear()
agg={}
for (s,d),c in zip(hangs,owners):
    o=c.most_common(1)[0][0] if c else 'Otro'
    a=agg.setdefault(o,[0,0.0,0.0]); a[0]+=1; a[1]+=d/1e6; a[2]=max(a[2],d/1e6)
for o,(n,tot,mx) in sorted(agg.items()): print(f"{sys.argv[3]} · {o}: {n} bloqueos · {tot/1000:.1f} s · máx {mx:.0f} ms")
