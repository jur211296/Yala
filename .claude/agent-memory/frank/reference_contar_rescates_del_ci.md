---
name: contar-rescates-del-ci
description: Cómo contar los «Rescatado al repetirlo» del job tests por prueba (anotaciones del check-run) y sacar la línea que falló del log; y que -test-iterations no repite Swift Testing.
metadata:
  type: reference
---

Los rescates del CI no están en ningún fichero: son anotaciones `warning` con título «Rescatado al repetirlo» en el
check-run del job `tests` (las pone `qa/scripts/ci-reintentar-rojos.sh`). Receta medida el 2026-11-17 (120 corridas,
unos 3 min):

```bash
for id in $(gh run list --workflow qa.yml --limit 120 --json databaseId -q '.[].databaseId'); do
  jid=$(gh api repos/jur211296/Yala/actions/runs/$id/jobs -q '.jobs[] | select(.name=="tests") | .id')
  [ -n "$jid" ] && gh api repos/jur211296/Yala/check-runs/$jid/annotations \
    -q '.[] | select(.title=="Rescatado al repetirlo") | "'$id' \(.message)"'
done
```

La línea exacta que cayó sale de `gh run view <id> --log | grep "✘ Test <nombre>"`. En zsh, una URL con `?` sin comillas
revienta con «no matches found».

Para repetir una familia de Swift Testing N veces, `-test-iterations` NO sirve (Xcode 27.2: corrió cada prueba una vez):
hacen falta N invocaciones de `xcodebuild test-without-building`, y con 10 núcleos ocupados en bucle se parece más al
runner lento. Ver [[un-timeout-tapa-el-rojo-de-detras]].
