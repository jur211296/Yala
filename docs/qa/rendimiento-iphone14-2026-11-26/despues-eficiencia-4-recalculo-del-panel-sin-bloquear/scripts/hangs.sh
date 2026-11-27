#!/bin/bash
# Uso: hangs.sh <etiqueta> <app>: instala, graba 35 s de arranque en frío con Time Profiler y resume potential-hangs.
S=/private/tmp/claude-501/-Users-max-jur-Claude-worktrees-Yala-2026-11-26-eficiencia-4-recalculo-del-panel-sin-bloquear/ff29ae48-f4ca-4aba-85ac-9d07f56ace3b/scratchpad
U=00008110-001A35A6267A401E
xcrun devicectl device install app --device $U $2 >/dev/null 2>&1 || { echo "no instaló"; exit 1; }
rm -rf $S/trazas/$1.trace
timeout 150 xcrun xctrace record --template 'Time Profiler' --device $U --output $S/trazas/$1.trace --time-limit 35s --launch -- com.jurgenschmidt.yala.dev -uitest -uitest-skip-onboarding > $S/trazas/$1.log 2>&1
xcrun xctrace export --input $S/trazas/$1.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="potential-hangs"]' > $S/trazas/$1-hangs.xml 2>/dev/null
python3 - $S/trazas/$1-hangs.xml $1 <<'PY'
import sys,xml.etree.ElementTree as ET
root=ET.parse(sys.argv[1]).getroot(); ids={}; d=[]
for row in root.iter('row'):
    for el in row:
        node=ids.get(el.get('ref'),el)
        if el.get('id'): ids[el.get('id')]=el
        if el.tag=='duration': d.append(int(node.text)/1e6)
d.sort(reverse=True)
print(f"{sys.argv[2]}: {len(d)} bloqueos >250 ms · total {sum(d)/1000:.1f} s · máx {d[0] if d else 0:.0f} ms · >1 s: {sum(1 for x in d if x>1000)} · top5 {[round(x) for x in d[:5]]}")
PY
