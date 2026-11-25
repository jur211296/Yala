#!/usr/bin/env bash
# Banco de `ci-fechas-desde-cache.py` (2026-11-25). Corre en el job `coverage-index`.
#
#   bash qa/scripts/ci-fechas-desde-cache-test.sh
#
# Lo que no puede fallar: un fichero que cambió desde el commit de la caché recibe una fecha MÁS
# NUEVA que cualquier build anterior (si no, el build lo da por al día y el binario sale viejo con el
# CI en verde: medido el 25-nov), y uno que no cambió recibe la fija (si no, la caché no sirve). Y si
# no se puede comparar con la caché, todo con la fecha de ahora (build completo, como antes).
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-fechas-desde-cache.py"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fallos=0
FIJA=315532800
es() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FALLO $1: «$2» ≠ «$3»"; fallos=$((fallos+1)); fi; }
reciente() { # reciente <desc> <fichero>: fecha de hace menos de un minuto
  local t; t=$(mt "$2"); if [ $(( $(date +%s) - t )) -lt 60 ]; then echo "ok   $1"; else echo "FALLO $1: fecha $t"; fallos=$((fallos+1)); fi; }
mt() { python3 -c 'import os,sys; print(int(os.lstat(sys.argv[1]).st_mtime))' "$1"; }
g() { git -C "$T/repo" -c user.email=t@t -c user.name=t "$@"; }

# Un «origin» con dos commits: el de la caché y el del PR.
git init -q --bare "$T/origin.git"
git init -q "$T/repo"
( cd "$T/repo" && mkdir -p d && echo uno > d/f.swift && echo dos > g.swift && echo tres > h.swift \
  && printf 'k = 1\n' > Secrets.xcconfig.template )
g add -A; g commit -qm cache; CACHE=$(g rev-parse HEAD)
g remote add origin "$T/origin.git"; g push -q origin HEAD:refs/heads/2.3
echo uno-bis > "$T/repo/d/f.swift"; echo nuevo > "$T/repo/nuevo.swift"; g rm -q h.swift
g add -A; g commit -qm pr; PR=$(g rev-parse HEAD)
g push -q origin HEAD:refs/heads/pr
cp "$T/repo/Secrets.xcconfig.template" "$T/repo/Secrets.xcconfig"

# El checkout del CI: clon superficial del PR, sin el commit de la caché.
git clone -q --depth=1 --branch pr "file://$T/origin.git" "$T/ci"
cp "$T/ci/Secrets.xcconfig.template" "$T/ci/Secrets.xcconfig"
python3 "$SCRIPT" --raiz "$T/ci" --clave "ddp-v2-Xcode-27.1-abc-$CACHE" Secrets.xcconfig > "$T/sal"; ex=$?
es "1 sale con 0" "$ex" "0"
reciente "2 el fichero cambiado, con la fecha de ahora" "$T/ci/d/f.swift"
reciente "3 el fichero nuevo, con la fecha de ahora" "$T/ci/nuevo.swift"
es "4 el que no cambió, con la fija" "$(mt "$T/ci/g.swift")" "$FIJA"
es "5 el extra sin seguimiento, con la fija" "$(mt "$T/ci/Secrets.xcconfig")" "$FIJA"
es "6 baja el commit de la caché aunque el clon sea superficial" "$(grep -c "caché de ${CACHE:0:12}" "$T/sal")" "1"

# 7. Sin caché restaurada: todo fijo (el DerivedData está vacío; el build es completo igual).
python3 "$SCRIPT" --raiz "$T/ci" --clave "" Secrets.xcconfig >/dev/null
es "7 sin caché, el cambiado también fijo" "$(mt "$T/ci/d/f.swift")" "$FIJA"

# 8. Clave sin SHA al final: todo con la fecha de ahora (build completo, correcto).
python3 "$SCRIPT" --raiz "$T/ci" --clave "ddp-v2-Xcode-27.1-abc-" Secrets.xcconfig >/dev/null
reciente "8 clave sin SHA, el que no cambió con la de ahora" "$T/ci/g.swift"

# 9. SHA que no existe en origin: todo con la fecha de ahora.
python3 "$SCRIPT" --raiz "$T/ci" --clave "ddp-v2-x-p-0123456789abcdef0123456789abcdef01234567" >/dev/null
reciente "9 SHA inexistente, el que no cambió con la de ahora" "$T/ci/g.swift"

# 10. Caché del mismo commit (un re-run): nada cambia, todo fijo.
python3 "$SCRIPT" --raiz "$T/ci" --clave "ddp-v2-x-p-$PR" >/dev/null
es "10 mismo commit, el del PR también fijo" "$(mt "$T/ci/d/f.swift")" "$FIJA"

# 11. Un cambio sin commit después del checkout también cuenta como cambiado.
echo dos-bis > "$T/ci/g.swift"
python3 "$SCRIPT" --raiz "$T/ci" --clave "ddp-v2-x-p-$PR" >/dev/null
reciente "11 cambio sin commit, con la fecha de ahora" "$T/ci/g.swift"
git -C "$T/ci" checkout -q -- g.swift

# 12. Fuera de un repo git: sale con 1.
mkdir -p "$T/nogit"; python3 "$SCRIPT" --raiz "$T/nogit" >/dev/null 2>&1; es "12 sin git sale con 1" "$?" "1"

echo
if [ "$fallos" -eq 0 ]; then echo "ci-fechas-desde-cache-test: todo ok"; exit 0; fi
echo "ci-fechas-desde-cache-test: $fallos fallo(s)"; exit 1
