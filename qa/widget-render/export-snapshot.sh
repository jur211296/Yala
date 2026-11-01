#!/bin/bash
# Exporta la foto que la app escribe en el App Group (la que leen los widgets) a un plist.
#   export-snapshot.sh <foto.plist>
# Antes: Yala Dev lanzada en el simulador con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista`
# y relanzada SIN reset ni seed (el primer arranque escribe la foto antes de sembrar).
set -euo pipefail
OUT="${1:?foto.plist}"
UDID="${WIDGET_RENDER_UDID:-CA0A0420-70CD-40FD-B44D-075CEC5F4F98}"
GROUP="${WIDGET_RENDER_GROUP:-group.com.jurgenschmidt.yala.dev}"
DIR="$(xcrun simctl get_app_container "$UDID" com.jurgenschmidt.yala.dev "$GROUP")"
SRC="$DIR/Library/Preferences/$GROUP.plist"
[ -f "$SRC" ] || { echo "export: no está $SRC"; exit 1; }
cp "$SRC" "$OUT"
/usr/bin/python3 - "$OUT" <<'PY'
import plistlib, sys, json, datetime
d = plistlib.load(open(sys.argv[1], 'rb'))
snap = d.get('widget_data_cache')
if not snap:
    sys.exit("export: la foto no trae widget_data_cache")
s = json.loads(snap)
print("export: foto de", s.get('lastUpdated'), "·", len(s.get('transactions', [])), "registros ·",
      len(s.get('budgets', [])), "presupuestos ·", len(s.get('scheduledPayments', [])), "pagos ·",
      "claves:", sorted(k for k in d if not k.startswith('widget_data_cache')))
PY
